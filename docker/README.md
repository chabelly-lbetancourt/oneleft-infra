# Entorno de desarrollo con Docker Compose

Levanta en local todas las dependencias que necesitan los microservicios de OneLeft.

## Uso

```bash
cd docker
cp .env.example .env      # credenciales solo para desarrollo local
docker compose up -d
docker compose ps         # todos los servicios deben aparecer como (healthy)
```

Para pararlo: `docker compose down` (conserva los datos) o `docker compose down -v` (borra también los volúmenes).

Con observabilidad (Prometheus, Loki y Grafana):

```bash
docker compose --profile observability up -d
```

## Servicios

| Servicio | Imagen | Puerto | Uso en OneLeft |
|---|---|---|---|
| PostgreSQL + PostGIS | `imresamu/postgis:17-3.5` | 5432 | Una base de datos por microservicio; PostGIS en `plans` |
| Redis | `redis:8-alpine` | 6379 | Posiciones en tiempo real (GEO), bloqueos distribuidos y caché |
| RabbitMQ | `rabbitmq:4-management-alpine` | 5672 · 15672 (consola) | Eventos entre microservicios |
| Keycloak | `quay.io/keycloak/keycloak:26.5` | 8180 | Identidad: OAuth2 / OpenID Connect |
| Mailpit | `axllent/mailpit:v1.27.0` | 1025 (SMTP) · 8025 (bandeja) | Captura los correos de Keycloak sin enviarlos (HU-067) |

Se usa `imresamu/postgis` porque la imagen oficial `postgis/postgis` solo se publica para `amd64`, y el
entorno de desarrollo es un Mac con Apple Silicon (`arm64`). Es la variante multiarquitectura que mantiene uno
de los responsables de la imagen oficial.

## Microservicios en contenedores (perfil `backend`)

Con `oneleft-backend` clonado junto a `oneleft-infra` y sus JAR compilados:

```bash
(cd ../../oneleft-backend && ./mvnw -DskipTests package)
docker compose --profile backend --profile observability up -d --build
```

| Contenedor | Puerto | Notas |
|---|---|---|
| `oneleft-gateway` | 8080 | Swagger UI en <http://localhost:8080/swagger-ui.html> |
| `oneleft-users` | 8081 | |
| `oneleft-plans` | 8082 | |
| `oneleft-notifications` | 8083 | Avisos de planes cercanos (HU-006); Web Push con las claves VAPID de `.env` |

- **Tokens dentro de Docker:** Keycloak se configura con `KC_HOSTNAME=http://localhost:8180`, de modo que los
  tokens siempre llevan como emisor la URL pública, y con `KC_HOSTNAME_BACKCHANNEL_DYNAMIC` para que los
  contenedores descarguen sus claves por la red interna (`KEYCLOAK_JWKS=http://keycloak:8180/...`).
- **Realm ya creado:** el realm solo se importa en el primer arranque. Para aplicar cambios del cliente
  `oneleft-web` (por ejemplo, la URI de redirección de Swagger UI) a un Keycloak ya en marcha:
  `keycloak/sync-web-client.sh`.
- Los contenedores envían sus logs a Loki y Prometheus los alcanza en los mismos puertos publicados.
- **Datos de demostración (seed):** los servicios arrancan con los perfiles `observability,seed`: perfiles de
  `ana@oneleft.dev` y `admin@oneleft.dev` y 8 planes alrededor de Vallecas que empiezan en las próximas horas. Para
  arrancar sin datos, usa `SPRING_PROFILES_ACTIVE=observability docker compose --profile backend up -d`. Los usuarios
  de prueba tienen ids fijos en el realm para que el seed los enlace. En `notifications`, Lucía y Admin tienen los
  avisos activados alrededor de Vallecas: un plan que publique Ana allí les llega al momento.
- **Web Push (HU-006):** `notifications` firma los avisos con un par de claves VAPID. Se generan una vez con
  `./generate-vapid-keys.sh --write`, que las escribe en `.env` (nunca en el repositorio). Sin ellas, los avisos solo
  llegan dentro de la app. Cambiarlas invalida las suscripciones de los navegadores.
- **Correos de Keycloak (HU-067):** al registrarse con correo y contraseña hay que verificar el correo antes de
  entrar, y «¿Has olvidado tu contraseña?» envía un enlace para cambiarla. Quien entra con Google no verifica nada
  (`trustEmail`). En local, Keycloak envía por SMTP a Mailpit, que no los reenvía a nadie: se leen en
  <http://localhost:8025>. En producción se rellenan las variables `SMTP_*` de `.env` con un servidor real (por
  ejemplo, Amazon SES con `SMTP_AUTH=true` y `SMTP_STARTTLS=true`). Los correos salen en el idioma de la persona. Para
  aplicarlo a un Keycloak ya creado: `keycloak/sync-email.sh`.
- **Migraciones reescritas:** si Flyway no arranca porque una migración ya aplicada ha cambiado (por ejemplo, al
  renombrarlas al inglés en backend#33), vacía la base de datos del servicio y reinícialo:
  `postgres/reset-service-database.sh plans` (o `users`). Solo en local: borra los datos de ese servicio.

## Observabilidad (perfil `observability`)

| Servicio | Imagen | Puerto | Uso |
|---|---|---|---|
| Prometheus | `prom/prometheus:v3.15.0` | 9090 | Métricas de los microservicios (`/actuator/prometheus`), Keycloak y RabbitMQ |
| Loki | `grafana/loki:3.7.8` | 3100 | Logs de los microservicios |
| Grafana | `grafana/grafana:13.2.2` | 3000 | Dashboards; acceso de lectura sin login en local |

- Los microservicios se ejecutan en el equipo (IntelliJ o `java -jar`), así que Prometheus los alcanza en
  `host.docker.internal:8080-8083` ([`observability/prometheus.yml`](observability/prometheus.yml)).
- Para enviar logs a Loki, los servicios se arrancan con el perfil `observability`
  (`SPRING_PROFILES_ACTIVE=observability`).
- Las fuentes de datos y el dashboard **OneLeft · Microservicios** se aprovisionan automáticamente desde
  [`observability/grafana`](observability/grafana): servicios activos, peticiones por segundo, latencia p95,
  porcentaje de errores 5xx, peticiones y latencia por servicio, respuestas por código HTTP, memoria de la JVM y logs.

Grafana: <http://localhost:3000> · Prometheus: <http://localhost:9090/targets>

## Bases de datos

El script [`postgres/init/01-databases.sql`](postgres/init/01-databases.sql) crea, en el primer arranque, una base
de datos por servicio (patrón *database per service*): `users`, `plans`, `chat`, `notifications`, `ai` y
`keycloak`, y activa PostGIS en `plans`.

## Keycloak

Al arrancar se importa el realm [`keycloak/oneleft-realm.json`](keycloak/oneleft-realm.json):

| Elemento | Valor |
|---|---|
| Realm | `oneleft` (issuer `http://localhost:8180/realms/oneleft`) |
| Roles | `user` (por defecto) y `admin` |
| Cliente `oneleft-web` | Público, Authorization Code + PKCE (S256), para la app web (`localhost:4200`) y Android (`https://localhost`, `oneleft://`) |
| Cliente `oneleft-api` | Confidencial, *client credentials*, para pruebas de integración |
| Usuarios de prueba | `ana@oneleft.dev` (user), `admin@oneleft.dev` (user, admin) y `lucia@oneleft.dev` (user, para los flujos de tres personas como la lista de espera), con las contraseñas definidas en el fichero del realm. En un Keycloak ya en marcha: `keycloak/sync-test-users.sh` |
| Proveedor `google` | «Continuar con Google» (HU-021). El *client id* y el secreto se leen de `GOOGLE_CLIENT_ID` y `GOOGLE_CLIENT_SECRET` del `.env` |
| Tema de login `oneleft` | `keycloak/themes/oneleft`: hereda de `keycloak.v2` con la identidad de la web (tipografías, colores, logo y textos es/en). En un Keycloak ya en marcha: `keycloak/sync-login-theme.sh` |

Consola de administración: <http://localhost:8180/admin> con las credenciales de `KEYCLOAK_ADMIN` del `.env`.

### Inicio de sesión con Google

1. En [Google Cloud Console](https://console.cloud.google.com), proyecto `OneLeft`: pantalla de consentimiento
   (audiencia externa, en modo prueba, con los correos de prueba) y un cliente OAuth de tipo *Aplicación web* con la
   URI de redirección `http://localhost:8180/realms/oneleft/broker/google/endpoint`.
2. Copiar el ID y el secreto del cliente en `GOOGLE_CLIENT_ID` y `GOOGLE_CLIENT_SECRET` del `.env`.
3. `docker compose up -d keycloak` y, si el realm ya estaba importado, `keycloak/sync-identity-providers.sh`
   (actualiza el proveedor sin perder las cuentas ya enlazadas).

La primera vez que alguien entra con Google se crea su cuenta con el rol `user`, y el perfil toma el nombre de Google.
Si ya existe una cuenta con el mismo correo, Keycloak pide confirmar con la contraseña de esa cuenta y las enlaza, en
lugar de crear otra.

> Todas las credenciales de este directorio son **solo para desarrollo local**. En AWS se usan secretos
> gestionados con AWS Secrets Manager.

## Comprobación rápida

```bash
# Token de prueba con el cliente oneleft-api
curl -s -X POST http://localhost:8180/realms/oneleft/protocol/openid-connect/token \
  -d grant_type=client_credentials -d client_id=oneleft-api -d client_secret=oneleft-api-dev-secret

# PostGIS
docker exec oneleft-postgres psql -U oneleft -d plans -c "select postgis_full_version();"
```
