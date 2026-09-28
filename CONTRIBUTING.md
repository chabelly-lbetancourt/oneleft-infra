# Cómo contribuir a OneLeft

Este documento recoge la política de trabajo común a todos los repositorios de OneLeft
(`oneleft-backend`, `oneleft-frontend`, `oneleft-infra` y `oneleft-docs`).

## Gestión del trabajo

- Todo el trabajo se planifica en el tablero [OneLeft · TFM](https://github.com/users/chabelly-lbetancourt/projects/4).
- Flujo del tablero: **Backlog → Sprint Backlog → In Progress → Done**.
- Límite de trabajo en curso (WIP): **máximo 2 tarjetas** en *In Progress*.
- Sprints **semanales** (de lunes a domingo). La estimación se hace en **puntos de historia**.
- Cada cambio nace de un **issue**: historia de usuario (`HU-XXX`), tarea técnica o bug.

## Estrategia de ramas

| Rama | Uso |
|---|---|
| `main` | Estado desplegado en producción. Solo recibe fusiones desde `dev` o `hotfix/*`. |
| `dev` | Integración continua del trabajo en curso. Rama por defecto. |
| `issue#<número>` | Una rama de vida corta por issue. Ejemplo: `issue#12`. |
| `hotfix/<descripción>` | Correcciones urgentes sobre producción. Ejemplo: `hotfix/login-caido`. |

## Mensajes de commit

Se sigue [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/) y **todo commit referencia su issue**:

```
<tipo>(<ámbito opcional>): <descripción en minúsculas> #<issue>
```

Tipos permitidos: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Ejemplos:

```
feat(planes): publicar un plan con plazas libres #6
fix(auth): renovar el token al volver de segundo plano #4
docs: añadir diagrama de arquitectura #3
```

El workflow `lint` valida automáticamente el nombre de la rama y los mensajes de commit en cada push y pull request.

## Pull requests

1. Crea la rama `issue#<número>` desde `dev`.
2. Abre la pull request contra `dev` y enlaza el issue con `Closes #<número>`.
3. La PR solo se fusiona si pasan todos los checks (lint, tests, cobertura y quality gate de SonarQube cuando aplique).

## Definición de terminado

- Criterios de aceptación del issue cumplidos.
- Tests automatizados y cobertura mínima del **80 %** en el código nuevo.
- Sin incidencias bloqueantes en SonarQube.
- Documentación actualizada y, si procede, capturas añadidas en `oneleft-docs/proceso`.
