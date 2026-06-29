# Assessment Overview

This document is the navigation entry point for all supplementary analysis generated for the ContosoUniversity application assessment. Each document below provides a focused view of a specific aspect of the application architecture and codebase.

## Supplementary Documents

| Document | Description |
|---|---|
| [Architecture Diagram](./architecture-diagram.md) | Two-layer visualization of the application architecture: a high-level diagram showing technology layers, data storage, and external services; and a component-level diagram showing how controllers, services, and data access components interact. |
| [Dependency Map](./dependency-map.md) | Visual map of all 47 declared NuGet packages grouped by functional category (web frameworks, ORM/database, security, client-side UI, messaging, utilities), with version compatibility risks and notable observations. |
| [API & Service Contracts](./api-service-contracts.md) | Inventory of all 29 HTTP endpoints across 6 controllers, JSON contract definitions, MSMQ-based notification communication patterns, and a sequence diagram of the primary request flow. |
| [Data Architecture](./data-architecture.md) | Entity model with ER diagram covering 8 domain entities (Student, Instructor, Course, Department, Enrollment, CourseAssignment, OfficeAssignment, Notification), EF Core configuration, data access patterns, and PII/sensitivity classification. |
| [Configuration Inventory](./configuration-inventory.md) | Comprehensive inventory of all configuration sources (`Web.config`, code-based startup), property keys and values, build profiles, secrets handling, and framework/runtime version catalog. |
| [Business Workflows](./business-workflows.md) | End-to-end documentation of the 5 primary business workflows (student enrolment, course creation with file upload, department editing with optimistic concurrency, instructor course assignment, notification polling), business rules, validation constraints, and decision logic. |
