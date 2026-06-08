# Assessment Overview

This directory contains supplementary analysis documents generated alongside the core AppCAT assessment report. Each document covers a specific aspect of the ContosoUniversity ASP.NET MVC 5 application to support cloud migration planning.

## Supplementary Documents

| Document | Description |
|----------|-------------|
| [architecture-diagram.md](./architecture-diagram.md) | Two-layer architecture visualization: high-level application architecture (technology stack, data storage, external services) and detailed component relationships (controllers, services, data access layer). |
| [dependency-map.md](./dependency-map.md) | Visual map of all 47 declared NuGet dependencies grouped by functional category (web frameworks, ORM, messaging, security, front-end, utilities), with version/compatibility risk analysis. |
| [api-service-contracts.md](./api-service-contracts.md) | Full inventory of all 40 MVC action endpoints across 6 controllers, communication patterns (synchronous HTTP + MSMQ async), DTOs and contracts, and security posture assessment. |
| [data-architecture.md](./data-architecture.md) | Database configuration, entity model ER diagram (9 entities), EF Core data access patterns, caching strategy (none), and data sensitivity/PII classification. |
| [configuration-inventory.md](./configuration-inventory.md) | Comprehensive inventory of all configuration sources (Web.config, Views/Web.config), build profiles (Debug/Release), properties inventory, startup dependency chain, and secrets handling. |
| [business-workflows.md](./business-workflows.md) | Core business workflows documented end-to-end: student registration, course creation with file upload, instructor assignment management, department concurrency handling, and MSMQ notification polling. |
