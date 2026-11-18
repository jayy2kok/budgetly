# Engineering Standards & Agent Rules

&lt;!--
Maintainer Notes (Block HTML comments are stripped by Claude Code before context injection):
- Global scope: Copy to ~/.claude/CLAUDE.md (or %USERPROFILE%\.claude\CLAUDE.md on Windows).
- Project scope: Copy to ./CLAUDE.md or ./.claude/CLAUDE.md at the repository root.
--&gt;

## Tech Stack & Dependencies
- **Target Stack**: Java 25, Spring Boot 4.x, Maven, React, and Flutter.
- **Version Policy**: Always initialize new projects and dependencies on the latest LTS or stable release. Never introduce deprecated libraries, APIs, or frameworks.
- **Skill Routing**: Invoke the matching skill before planning or writing stack-specific code:
  - Backend (Java / Spring Boot): `java-springboot`
  - UI/UX & Component Architecture: `frontend-design`
  - React Frontend: `react-best-practices`
  - Flutter Client: `flutter-expert`

## Project Context, Living Documentation & Diagrams
Before planning or writing code, check the repository root for these living documents and keep them synchronized as the system evolves:
- **`requirements.md`**: Read if present to align with functional and non-functional requirements; update when requirements change.
- **`design.md` / `architecture.md`**: Read if present to follow end-to-end system design and component boundaries; update when architectural decisions change.
- **`ERD.md`**: Create and maintain `ERD.md` to document the database schema, tables, relationships, and constraints. Keep it synchronized with every schema or entity migration.
- **`TODO.md`**: Read if present before starting work to check pending tasks, and update task status immediately upon completing milestones.
- **Mermaid Diagrams Everywhere**: Always use **Mermaid** syntax (`flowchart`, `sequenceDiagram`, `erDiagram`, `classDiagram`) inside `design.md`, `architecture.md`, and `ERD.md` to visualize system architecture, execution workflows, and data models. Update diagrams alongside code changes.

## API & Data Modeling Standards (Contract-First)
- **Contract-First OpenAPI Design**: Define or update the OpenAPI specification (`openapi.yaml` / `openapi.json`) *before* implementing or modifying endpoints. All controller implementations and client integrations must strictly conform to the OpenAPI contract.
- **Reuse OpenAPI-Generated Models & Clients**: Always use OpenAPI-generated DTOs, models, and client SDKs across backend and frontend interactions (e.g., via Maven OpenAPI generator plugins and TypeScript/Dart client generators). Never hand-write duplicate request/response models.
- **Documented & Aligned Database Entities**: Ensure database entity models (e.g., JPA/Hibernate `@Entity` classes) are thoroughly documented, reflect the schema in `ERD.md`, and closely align with the OpenAPI domain models without redundant mapping layers.

## Core Design Principles (YAGNI & SOLID)
The most reliable code is the code that never had to be written. Adhere strictly to **YAGNI** (*You Aren't Gonna Need It*) and **SOLID** principles:
- **Smallest Working Change**: Implement the minimal change required to satisfy current, validated requirements.
- **No Premature Abstraction**: Avoid unrequested abstractions, premature generalization, defensive scaffolding, speculative features, or extraneous architectural layers.
- **Reuse First**: Reuse existing project code, OpenAPI-generated types, patterns, and standard library components before introducing new implementations.
- **Deterministic & Low-Boilerplate**: Favor deterministic, low-boilerplate solutions using the standard library with clear single-responsibility boundaries and dependency inversion.
- **Self-Documenting Naming**: Use descriptive, intention-revealing names for variables, methods, classes, and database columns. Avoid abbreviations unless universally standard (e.g., `id`, `url`, `dto`, `http`, `erd`).

## Testing & Verification Strategy
- **Completion Gate — Mandatory E2E Testing**: Before claiming any task is completed, perform end-to-end testing of the delivered functionality and confirm real, passing results. Compilation, static analysis, linting, or code review alone never constitute completion.
- **Blocked E2E Testing — Disclose & Guide**: If end-to-end testing cannot be performed (e.g., missing emulator/device, build failure, missing credentials, environment unavailable, or tooling limitations), do NOT claim the task is completed. Instead: (1) clearly state that E2E testing was not performed and explicitly list each blocking reason; (2) provide step-by-step instructions the user can follow to resolve the blockers and run the E2E verification themselves (e.g., how to create/launch the emulator, install the build, run the test suite, and what a passing result looks like); (3) suggest alternatives if applicable.
- **Mobile App E2E Testing (Local Emulators)**: For mobile app tasks, run E2E verification on the local Android emulator **`Pixel_9a_jayraj`** (primary); if required (e.g., multi-device coverage or parallel runs), also use **`Pixel_9a_jayy2kok`**. Launch the emulator, install the build, execute the integration/E2E suite, and verify the app behaves correctly on the emulator before declaring the task complete.
- **End-to-End Coverage**: Write E2E tests for every new feature and bug fix, explicitly covering both happy paths and edge/error cases.
- **High-Signal Unit & Integration Tests**: Focus unit and integration tests on domain business logic, service layers, contract compliance, and integration boundaries.
- **No Trivial Boilerplate Tests**: Do NOT write unit tests for simple getters, setters, records, or logic-free/OpenAPI-generated DTOs.
- **Local Verification Environment**: Prefer Docker for local development and test execution when available (`docker compose up -d`). Verify prototypes and end-to-end API flows against the Docker Compose environment before marking work complete.

## Git & Branching Workflow
- **Branch Isolation**: Always work on `feature/*` or `bugfix/*` branches (`git checkout -b feature/<name>` or `bugfix/<name>`).
- **Protected Main**: Never commit or push directly to `main` or `master`.
- **Atomic Commits**: Commit frequently in small, logical increments with clear, imperative commit messages.

## Stack-Specific Style & Linting Gates
Run the relevant linter, code generator, and static analysis checks before committing:
- **Java (Java 25 / Spring Boot 4.x / Maven)**:
  - Follow the **Google Java Style Guide** and enforce zero Checkstyle or SonarLint violations.
  - Verify with: `mvn clean compile checkstyle:check test`
- **React (JavaScript / TypeScript)**:
  - Follow the **Airbnb JavaScript Style Guide** and enforce clean formatting via ESLint and Prettier.
  - Verify with: `npm run lint && npx prettier --check .`
- **Flutter (Dart)**:
  - Follow the **Official Flutter Style Guide** and enforce strict lint rules via Dart Analysis and `flutter_lints`.
  - Verify with: `dart analyze && flutter test`