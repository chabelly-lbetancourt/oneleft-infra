# Entornos desplegados (pre y pro) con Docker Compose

[`compose.prod.yaml`](compose.prod.yaml) define un entorno desplegado de OneLeft: una instancia de AWS Lightsail
(Linux, 2 vCPU, 8 GB) por entorno, con las imágenes publicadas en GHCR (infra#4). El despliegue desde GitHub Actions
es infra#5.

## Cómo queda

- **Caddy es la única entrada** (puertos 80 y 443) y obtiene solo el certificado de Let's Encrypt para
  `ONELEFT_DOMAIN`. Desde el mismo origen sirve:

  | Ruta | Destino |
  |---|---|
  | `/auth/*` | Keycloak (`KC_HTTP_RELATIVE_PATH=/auth`), en modo producción (`start`) detrás del proxy |
  | `/api/*`, `/share/*`, `/api-docs/*`, `/swagger-ui*`, `/v3/api-docs*` | gateway |
  | `/grafana*` | Grafana, con su propio inicio de sesión (perfil `observability`) |
  | el resto | la web (nginx), que lleva cualquier ruta de la app a `index.html` |

- **Ningún otro puerto sale de la instancia**: PostgreSQL, Redis, RabbitMQ, Keycloak y los servicios solo se ven
  dentro de la red de Compose.
- **Imágenes:** `ghcr.io/chabelly-lbetancourt/oneleft-*`, con la etiqueta `latest` en pro y `pre` en pre
  (`ONELEFT_IMAGE_TAG`). La web no lleva ningún host compilado (`environment.pre.ts` y `environment.pro.ts`), así que
  la misma imagen vale para cualquier dominio.
- **El gateway detrás de Caddy** (`SERVER_FORWARD_HEADERS_STRATEGY=native`) toma la IP del cliente de
  `X-Forwarded-For`, así que el límite de peticiones sin sesión sigue siendo por persona y no por el proxy.
- **Datos de demostración:** pro nunca los carga (los *seeders* solo corren con `seed` y sin `pro`); pre los activa con
  `SPRING_PROFILES_ACTIVE=seed`.

### Memoria en una instancia de 8 GB

Cada contenedor tiene su límite (`mem_limit`), y cada JVM su `-Xmx` por debajo de él: así, un servicio que crece no
deja sin memoria a los demás (en local, con 3,8 GB para Docker, ya pasó en las entradas 13 y 14 del diario).

| Contenedor | Límite | JVM |
|---|---|---|
| gateway, users, social | 512 MB | `-Xmx288m` |
| plans | 640 MB | `-Xmx384m` |
| notifications, chat, reputation | 448 MB | `-Xmx256m` |
| Keycloak | 768 MB | `-Xmx512m` |
| PostgreSQL | 1 GB | `shared_buffers=256MB` |
| RabbitMQ | 384 MB | |
| Redis | 128 MB | `maxmemory 96mb`, se descartan primero las claves más antiguas |
| Caddy, la web, la copia | 128, 64 y 256 MB | |
| **Total** | **6,1 GB** | quedan unos 1,9 GB para el sistema y Docker |
| Observabilidad (opcional) | 768 MB | Prometheus 192, Loki 192 y Grafana 384 |

## Variables y secretos

Todo lo que cambia entre entornos va en un `.env` de la instancia, a partir de
[`.env.prod.example`](.env.prod.example). Ese `.env` no se sube nunca al repositorio. Las contraseñas tienen que ser
largas y aleatorias (`openssl rand -base64 32`).

## El realm de Keycloak

El realm de desarrollo trae personas de prueba con contraseñas conocidas y las URL locales de la web, así que no se
importa tal cual. [`keycloak/render-prod-realm.py`](keycloak/render-prod-realm.py) genera a partir de él
[`keycloak/oneleft-realm.prod.json`](keycloak/oneleft-realm.prod.json):

- sin usuarios;
- el cliente `oneleft-web` solo acepta `https://${ONELEFT_DOMAIN}/*` y `oneleft://*` (la app Android). Keycloak
  rellena el marcador `${ONELEFT_DOMAIN}` al importarlo.

```bash
keycloak/render-prod-realm.py
```

La CI comprueba con `--check` que el realm de producción está al día. Si cambia el de desarrollo, hay que generarlo
de nuevo y subirlo en el mismo cambio. Como en local, el realm **solo se importa la primera vez**: en un entorno ya
desplegado, los cambios se aplican desde la consola (`https://<dominio>/auth/admin`). La persona administradora de la
app se crea también desde la consola.

## Copia diaria de PostgreSQL

El servicio `backup` (imagen [`backup/`](backup), construida en la instancia) hace cada día, a `BACKUP_TIME` (UTC),
un `pg_dumpall` comprimido: todas las bases de datos y sus roles. Lo sube a
`s3://$BACKUP_BUCKET/postgres/oneleft-<fecha>.sql.gz`, en un bucket privado de Lightsail, y borra las copias con más
de `BACKUP_KEEP_DAYS` días.

```bash
# Una copia ahora mismo
docker compose -f compose.prod.yaml run --rm backup now
```

Para restaurar una copia en un PostgreSQL vacío (con el resto de servicios parados), el mismo contenedor tiene `aws` y
`psql`:

```bash
docker compose -f compose.prod.yaml run --rm --entrypoint sh backup -c 'aws s3 cp "s3://$BACKUP_BUCKET/postgres/oneleft-<fecha>.sql.gz" - | gunzip | psql -d postgres'
```

## Puesta en marcha en la instancia

```bash
docker login ghcr.io
```

```bash
docker compose -f compose.prod.yaml pull
```

```bash
docker compose -f compose.prod.yaml up -d --wait
```

Con la observabilidad:

```bash
docker compose -f compose.prod.yaml --profile observability up -d --wait
```

`docker login` necesita un token de GitHub que solo pueda leer paquetes. Antes del primer arranque:

- el registro DNS del dominio debe apuntar a la IP estática de la instancia y los puertos 80 y 443 deben estar
  abiertos, para que Let's Encrypt pueda validar el dominio;
- el bucket de las fotos debe permitir `PUT` desde `https://<dominio>` (CORS);
- el cliente de Google debe tener la URI de redirección `https://<dominio>/auth/realms/oneleft/broker/google/endpoint`.

## Producción en local

La misma definición se prueba en el equipo con [`compose.prod.local.yaml`](compose.prod.local.yaml), que solo añade:

- Caddy en `https://localhost`, con su propia autoridad local;
- un servidor S3 (Versity) en lugar de los dos buckets de Lightsail;
- las imágenes compiladas en el equipo.

El stack de desarrollo se para antes, porque no caben los dos a la vez.

```bash
cd ../../oneleft-backend && ./mvnw -B -q -DskipTests package && for s in gateway users plans notifications chat social reputation; do docker build -q -t oneleft/$s:prod-local $s; done
```

```bash
cd ../../oneleft-frontend && docker build --build-arg CONFIGURATION=production --secret id=primeui,src=.env -t oneleft/web:prod-local .
```

```bash
docker compose --env-file .env.prod.local -f compose.prod.yaml -f compose.prod.local.yaml up -d --wait
```

`.env.prod.local` (no se sube) sigue `.env.prod.example` con:

- `ONELEFT_DOMAIN=localhost`, `HSTS_MAX_AGE=0`, `ONELEFT_IMAGES=oneleft/`, `ONELEFT_IMAGE_TAG=prod-local` y
  `SPRING_PROFILES_ACTIVE=seed`;
- los dos buckets apuntando a `http://storage:7070` (`STORAGE_PUBLIC_ENDPOINT=http://localhost:7070`).

Al terminar se borra todo, volúmenes incluidos:

```bash
docker compose --env-file .env.prod.local -f compose.prod.yaml -f compose.prod.local.yaml down -v
```
