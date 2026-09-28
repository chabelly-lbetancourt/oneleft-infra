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

- **Tokens dentro de Docker:** Keycloak se configura con `KC_HOSTNAME=http://localhost:8180`, de modo que los
  tokens siempre llevan como emisor la URL pública, y con `KC_HOSTNAME_BACKCHANNEL_DYNAMIC` para que los
  contenedores descarguen sus claves por la red interna (`KEYCLOAK_JWKS=http://keycloak:8180/...`).
- **Realm ya creado:** el realm solo se importa en el primer arranque. Para aplicar cambios del cliente
  `oneleft-web` (por ejemplo, la URI de redirección de Swagger UI) a un Keycloak ya en marcha:
  `keycloak/sincronizar-cliente-web.sh`.
- Los contenedores envían sus logs a Loki y Prometheus los alcanza en los mismos puertos publicados.

## Observabilidad (perfil `observability`)

| Servicio | Imagen | Puerto | Uso |
|---|---|---|---|
| Prometheus | `prom/prometheus:v3.15.0` | 9090 | Métricas de los microservicios (`/actuator/prometheus`), Keycloak y RabbitMQ |
| Loki | `grafana/loki:3.7.8` | 3100 | Logs de los microservicios |
| Grafana | `grafana/grafana:13.2.2` | 3000 | Dashboards; acceso de lectura sin login en local |

- Los microservicios se ejecutan en el equipo (IntelliJ o `java -jar`), así que Prometheus los alcanza en
  `host.docker.internal:8080-8082` ([`observability/prometheus.yml`](observability/prometheus.yml)).
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
| Usuarios de prueba | `ana@oneleft.dev` (user) y `admin@oneleft.dev` (user, admin), con las contraseñas definidas en el fichero del realm |

Consola de administración: <http://localhost:8180/admin> con las credenciales de `KEYCLOAK_ADMIN` del `.env`.

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
