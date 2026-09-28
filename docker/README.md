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
