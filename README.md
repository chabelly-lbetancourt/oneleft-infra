# OneLeft · Infraestructura

[![lint](https://github.com/chabelly-lbetancourt/oneleft-infra/actions/workflows/lint.yml/badge.svg?branch=dev)](https://github.com/chabelly-lbetancourt/oneleft-infra/actions/workflows/lint.yml)

**OneLeft** conecta planes para las próximas horas que tienen plazas libres («falta uno») con personas cercanas que pueden unirse en tiempo real.

## Contenido

- `docker/`: entorno de desarrollo con Docker Compose (PostgreSQL/PostGIS, Redis, RabbitMQ, Keycloak).
- `k8s/`: manifiestos de Kubernetes con autoescalado.
- `aws/`: despliegue en AWS.
- `observability/`: Grafana, Loki y Prometheus con dashboards versionados.

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
