# OneLeft · Infraestructura

[![lint](https://github.com/chabelly-lbetancourt/oneleft-infra/actions/workflows/lint.yml/badge.svg?branch=dev)](https://github.com/chabelly-lbetancourt/oneleft-infra/actions/workflows/lint.yml)

**OneLeft** conecta planes para las próximas horas que tienen plazas libres («falta uno») con personas cercanas que pueden unirse en tiempo real.

## Contenido

- [`docker/`](docker): entorno local con Docker Compose por perfiles: dependencias (PostgreSQL/PostGIS, Redis,
  RabbitMQ, Keycloak), `backend` (gateway, users, plans) y `observability` (Prometheus, Loki y Grafana con
  dashboards versionados en `docker/observability`).
- `k8s/` *(infra#4, pendiente)*: manifiestos de Kubernetes con Kustomize y autoescalado.
- `aws/` *(infra#5, pendiente)*: despliegue en AWS.

## Entornos

| Entorno | Rama | Dónde | Imágenes | Kubernetes |
|---|---|---|---|---|
| **dev** | `dev` | Equipo local con Docker Compose | Compiladas en local | — |
| **pre** (*staging*) | `pre` | AWS (EKS), mismo clúster que pro | `ghcr.io/chabelly-lbetancourt/oneleft-*:pre` | namespace `oneleft-pre` (overlay `k8s/overlays/pre`) |
| **pro** | `main` | AWS (EKS) | `ghcr.io/chabelly-lbetancourt/oneleft-*:latest` | namespace `oneleft-pro` (overlay `k8s/overlays/pro`) |

- `pre` es una copia a escala reducida de producción: mismas imágenes y manifiestos, con una réplica por servicio,
  su propia base de datos (esquema aparte en RDS) y su propio realm de Keycloak. Aquí se prueba todo antes de
  promocionar a `main`.
- En AWS, cada entorno sirve la web, el gateway (`/api`) y Keycloak (`/auth`) desde el mismo origen, detrás del
  balanceador. Así la web de `pre` no lleva ningún host compilado (ver `environment.pre.ts` en el frontend).
- El flujo de ramas y de promoción está en [CONTRIBUTING.md](CONTRIBUTING.md).

**Stack:** Docker · Kubernetes · AWS · Grafana · Loki · Prometheus · GitHub Actions

## Proyecto

| Repositorio | Contenido |
|---|---|
| [oneleft-backend](https://github.com/chabelly-lbetancourt/oneleft-backend) | Microservicios Spring Boot |
| [oneleft-frontend](https://github.com/chabelly-lbetancourt/oneleft-frontend) | App web Angular y app Android con Capacitor |
| [oneleft-infra](https://github.com/chabelly-lbetancourt/oneleft-infra) | Docker, Kubernetes, AWS y observabilidad |
| [oneleft-docs](https://github.com/chabelly-lbetancourt/oneleft-docs) | Memoria del TFM y documentación del proceso |

Tablero Kanban: [OneLeft · TFM](https://github.com/users/chabelly-lbetancourt/projects/4) · Normas de trabajo: [CONTRIBUTING.md](CONTRIBUTING.md)

---
Trabajo Fin de Máster · Máster Universitario en Ingeniería Web · ETSISI · Universidad Politécnica de Madrid
