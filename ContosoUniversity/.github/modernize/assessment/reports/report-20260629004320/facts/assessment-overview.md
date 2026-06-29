# Assessment Overview

This document provides a navigation entry point for all supplementary analysis documents generated as part of the ContosoUniversity application assessment.

## Supplementary Documents

| Document | Description |
|---|---|
| [Architecture Diagram](architecture-diagram.md) | Two-layer architecture visualization: high-level application architecture (technology stack, data storage, external services) and detailed component relationships (controllers, services, data access layer). |
| [Dependency Map](dependency-map.md) | Visual map of all external NuGet package dependencies grouped by functional category (web frameworks, database/ORM, messaging, security, front-end, utilities), with version and compatibility risk analysis. |
| [API & Service Communication Contracts](api-service-contracts.md) | Full inventory of all 39 HTTP action endpoints, JSON API endpoints, communication patterns (synchronous MVC + asynchronous MSMQ), DTOs and binding models, security posture, and a request-flow sequence diagram. |
| [Data Architecture & Persistence Layer](data-architecture.md) | Database configuration, EF Core entity model with ER diagram, data ownership, repository/query patterns, caching strategy, and data classification (PII/PHI fields). |
| [Configuration & Externalized Settings Inventory](configuration-inventory.md) | Complete inventory of all configuration sources (`Web.config`), application settings, connection strings, build/runtime profiles, startup sequence, secrets handling, and framework version catalog. |
| [Core Business Workflows](business-workflows.md) | End-to-end documentation of the five primary business workflows (student enrolment, course creation with file upload, instructor course assignment, department concurrency management, notification polling), business rules, validation constraints, and decision logic. |
