# Cómo contribuir a OneLeft

Este documento recoge la política de trabajo común a todos los repositorios de OneLeft
(`oneleft-backend`, `oneleft-frontend`, `oneleft-infra` y `oneleft-docs`).

## Gestión del trabajo

- Todo el trabajo se planifica en el tablero [OneLeft · TFM](https://github.com/users/chabelly-lbetancourt/projects/4).
- Flujo del tablero: **Backlog → Sprint Backlog → In Progress → Done**.
- Límite de trabajo en curso (WIP): **máximo 2 tarjetas** en *In Progress*.
- Sprints **semanales** (de lunes a domingo). Priorización **MoSCoW** y estimación en **puntos de historia** (Fibonacci).
- Cada tarjeta registra **Fecha inicio** y **Fecha fin** (dentro de su sprint) y, al terminar, el **Tiempo invertido**.
- Cada cambio nace de un **issue**: historia de usuario (`HU-XXX`), tarea técnica o bug. Si una historia toca otro
  repositorio, se crea allí una *sub-issue*.

## Entornos y estrategia de ramas

| Rama | Entorno | Uso |
|---|---|---|
| `dev` | **dev** (integración) | Rama por defecto. Recibe las PR de `issue#N`. Se prueba en local con Docker Compose |
| `pre` | **pre** (*staging*) | Candidata a producción: recibe `dev` cuando un conjunto de cambios está listo y se prueba completo. Imágenes `:pre` |
| `main` | **pro** (producción) | Estado desplegado en producción. Solo recibe `pre` o `hotfix/*`. Imágenes `:latest` |
| `issue#<número>` | — | Una rama de vida corta por issue, creada desde `dev`. Ejemplo: `issue#12` |
| `hotfix/<descripción>` | — | Corrección urgente creada desde `main`. Ejemplo: `hotfix/login-caido` |

```
issue#N ──PR──▶ dev ──PR (promoción)──▶ pre ──PR (release)──▶ main
                 ▲                        ▲                     │
                 └──────── hotfix/* ──────┴─────────────────────┘
```

- **Promoción a pre:** PR `dev → pre` cuando las historias del sprint están integradas. En `pre` se ejecutan todas
  las pruebas (unitarias, de integración y E2E con capturas) sobre las imágenes `:pre`.
- **Release a pro:** PR `pre → main` cuando `pre` está validado. Solo lo que ha pasado por `pre` llega a producción.
- **Hotfix:** rama `hotfix/*` desde `main`, PR a `main` y, después, la misma rama a `pre` y a `dev` para no perder el arreglo.
- El workflow `lint` rechaza cualquier otro camino (por ejemplo, `dev → main` o `issue#N → pre`).

## Idioma

- **Código en inglés:** comentarios, nombres de clases, métodos, variables, atributos, enumerados, mensajes de la
  API, logs, scripts y CI.
- **Textos de la app** en español e inglés, en los ficheros de traducción de `oneleft-frontend/public/i18n`.
- **Documentación del TFM** (memoria, diario, diagramas, issues y este documento) en español.

## Mensajes de commit

Se sigue [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/), en inglés, y **todo commit
referencia su issue**:

```
<type>(<optional scope>): <description in lower case> #<issue>
```

Tipos permitidos: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

```
feat(plans): nearby plans search with PostGIS #7
fix(auth): renew the token when the app comes back to the foreground #4
docs: add the architecture diagram #3
```

El workflow `lint` valida el nombre de la rama, el camino de promoción y los mensajes de commit en cada PR.

## Pull requests

1. Crea la rama `issue#<número>` desde `dev`.
2. Abre la PR contra `dev` y enlaza el issue con `Closes #<número>`.
3. La PR solo se fusiona si pasan todos los checks (lint, tests, cobertura y quality gate de SonarQube cuando aplique).

## Definición de terminado

- Criterios de aceptación del issue cumplidos.
- Tests automatizados y cobertura mínima del **80 %** en el código nuevo.
- Sin incidencias bloqueantes en SonarQube.
- Validado en **pre** antes de pasar a producción.
- Documentación actualizada y, si procede, capturas añadidas en `oneleft-docs/proceso`.
