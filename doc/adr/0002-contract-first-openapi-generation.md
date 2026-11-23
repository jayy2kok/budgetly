# ADR 0002: Contract-First OpenAPI Generation (openapi-generator-maven-plugin)

## Status
Accepted

## Context
The API contract is shared between the Spring Boot backend, the Flutter client, and documentation
(`design.md` §5, `ERD.md`). Hand-written DTOs and controller signatures drift from the spec over
time, and "the spec is documentation only" gives no safety net when a request/response model
changes. The API needed a single source of truth enforced at compile time on the server.

## Decision

1. **Single source of truth**: `budgetly_api/src/main/resources/api/budgetly-openapi.yml` is the
   canonical OpenAPI 3 contract. A stale root-level `api/budgetly-openapi.yml` was deleted
   (2026-11-22); the spec under `budgetly_api/src/main/resources/api/` is the only one.

2. **Compile-time generation**: `openapi-generator-maven-plugin` (7.27.0) runs during `mvn compile`
   and generates Spring interfaces and DTO models into `com.budgetly.api.generated.controller` and
   `com.budgetly.api.generated.model`. Two executions cover the API:
   - `generate-async-messages-api` — tag `Messages`, `async=true`, `interfaceOnly=true`;
   - `generate-other-apis` — tags `Auth`, `Categories`, `Dashboard`, `FamilyGroups`,
     `PatternRegistry`, `Transactions`, `interfaceOnly=true`.
   Both use `useSpringBoot4=true`, `useJakartaEe=true`, `useTags=true` (aligned with the Java 25 /
   Spring Boot 4 upgrade in ADR-0004).

3. **Controllers implement the generated interfaces** — every REST controller
   (`controller/PatternRegistryController`, `MessageController`, etc.) implements the
   OpenAPI-generated interface and reuses the generated DTO models. No hand-written duplicate
   request/response models on the server.

4. **Live documentation**: SpringDoc (`springdoc-openapi-starter-webmvc-ui` 3.2.0) serves the
   resolved contract at `/swagger-ui.html` and `/api-docs`, so the running API is always inspectable
   against the spec.

## Consequences
- **Compile-time contract adherence** — a spec change that breaks a generated interface fails the
  build, so the server cannot drift silently; review focuses on the spec and the thin controller
  layer.
- **Single source of truth for models** — generated DTOs are reused end-to-end (controllers,
  services, docs), eliminating redundant mapping layers (see CLAUDE.md API & Data Modeling
  Standards).
- **Maintenance burden is on the spec** — every new or changed endpoint must be threaded through
  the YAML by hand. The `PATCH /patterns/{id}/category` endpoint — like `GET /families/my`,
  `POST /families/join`, and `POST /messages/bulk` before it — was added beyond the original plan
  §6, and any gap between spec and code shows up as drift (the "API Contract Hygiene" item in
  `TODO.md`).
- **Client SDK generation is still pending** — the Flutter app's `app/lib/data/remote/` services
  are still hand-written Dio calls; regenerating the Dart client from the same spec and switching
  the app over is an open TODO, so today the contract protects the server side only.