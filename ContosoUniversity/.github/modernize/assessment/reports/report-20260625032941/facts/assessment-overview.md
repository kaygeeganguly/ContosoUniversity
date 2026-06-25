# Assessment Overview

This document provides navigation to all supplementary analysis documents generated for the ContosoUniversity assessment. Each document covers a distinct aspect of the application's architecture, dependencies, configuration, and business workflows.

## Supplementary Documents

| Document | Description |
|---|---|
| [Architecture Diagram](architecture-diagram.md) | Two-layer visualization of the application architecture: high-level component diagram (ASP.NET MVC, EF Core, MSMQ, SQL Server layers) and detailed component relationship diagram showing controller, service, and data access interactions. |
| [Dependency Map](dependency-map.md) | Visual map of all external NuGet dependencies grouped by functional category (Web Frameworks, Database/ORM, Messaging, Security, UI, Utilities), with version and compatibility risk analysis. |
| [API & Service Contracts](api-service-contracts.md) | Complete inventory of all 39 MVC action endpoints across 6 controllers, communication patterns (synchronous HTTP form-posts and MSMQ async notifications), DTOs, and security posture analysis. |
| [Data Architecture](data-architecture.md) | Entity model with Mermaid ER diagram for the 8 domain entities, database configuration (SQL Server, EF Core 3.1, EnsureCreated schema management), key data access patterns, and PII/data sensitivity classification. |
| [Configuration Inventory](configuration-inventory.md) | Comprehensive inventory of all configuration sources (Web.config), property keys and values, build/runtime profiles, startup dependency chain, and secrets provisioning approach. |
| [Business Workflows](business-workflows.md) | Documentation of core business workflows (student enrollment, course management, department administration, instructor assignment, notification polling), domain entities, business rules, validation constraints, and transaction boundaries. |
