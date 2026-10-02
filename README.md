# OneLeft · Infraestructura

[![lint](https://github.com/chabelly-lbetancourt/oneleft-infra/actions/workflows/lint.yml/badge.svg?branch=dev)](https://github.com/chabelly-lbetancourt/oneleft-infra/actions/workflows/lint.yml)

**OneLeft** conecta planes para las próximas horas que tienen plazas libres («falta uno») con personas cercanas que pueden unirse en tiempo real.

## Contenido

- [`docker/`](docker): entorno local con Docker Compose por perfiles: dependencias (PostgreSQL/PostGIS, Redis,
  RabbitMQ, Keycloak), `backend` (gateway, users, plans) y `observability` (Prometheus, Loki y Grafana con
  dashboards versionados en `docker/observability`).
- Compose de producción *(infra#4, pendiente)*: imágenes publicadas y Caddy con HTTPS como entrada única.
- Despliegue en AWS Lightsail *(infra#5, pendiente)*: una instancia por entorno, desplegada desde GitHub Actions.

## Entornos

| Entorno | Rama | Dónde | Imágenes |
|---|---|---|---|
| **dev** | `dev` | Equipo local con Docker Compose | Compiladas en local |
| **pre** (*staging*) | `pre` | Instancia de AWS Lightsail con Docker Compose (encendida para validar cada *release*) | `ghcr.io/chabelly-lbetancourt/oneleft-*:pre` |
| **pro** | `main` | Instancia de AWS Lightsail con Docker Compose | `ghcr.io/chabelly-lbetancourt/oneleft-*:latest` |

- `pre` es una copia de producción: mismas imágenes y misma definición de Compose, con su propia base de datos y su
  propio realm de Keycloak. Aquí se prueba todo antes de promocionar a `main`.
- En AWS, cada entorno sirve la web, el gateway (`/api`) y Keycloak (`/auth`) desde el mismo origen, detrás de Caddy
  (HTTPS automático). Así la web de `pre` no lleva ningún host compilado (ver `environment.pre.ts` en el frontend).
- El flujo de ramas y de promoción está en [CONTRIBUTING.md](CONTRIBUTING.md).

**Stack:** Docker · Docker Compose · AWS Lightsail · Caddy · Grafana · Loki · Prometheus · GitHub Actions

## Proyecto

| Repositorio | Contenido |
|---|---|
| [oneleft-backend](https://github.com/chabelly-lbetancourt/oneleft-backend) | Microservicios Spring Boot |
| [oneleft-frontend](https://github.com/chabelly-lbetancourt/oneleft-frontend) | App web Angular y app Android con Capacitor |
| [oneleft-infra](https://github.com/chabelly-lbetancourt/oneleft-infra) | Docker Compose, despliegue en AWS Lightsail y observabilidad |
| [oneleft-docs](https://github.com/chabelly-lbetancourt/oneleft-docs) | Memoria del TFM y documentación del proceso |

Tablero Kanban: [OneLeft · TFM](https://github.com/users/chabelly-lbetancourt/projects/4) · Normas de trabajo: [CONTRIBUTING.md](CONTRIBUTING.md)

---
Trabajo Fin de Máster · Máster Universitario en Ingeniería Web · ETSISI · Universidad Politécnica de Madrid
