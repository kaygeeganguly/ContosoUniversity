# Architecture Diagram

This document summarizes the ContosoUniversity application structure and key component interactions for the current single-project deployment.

## Application Architecture

```mermaid
flowchart TD
    subgraph Client["Client Layer"]
        Browser["Web Browser"]
    end

    subgraph App["Application Layer - ASP.NET MVC 5"]
        MVC["MVC Controllers and Razor Views"]
        Biz["Controller Business Logic"]
        Notify["Notification Service"]
    end

    subgraph Data["Data Layer"]
        EF["Entity Framework Core 3.1 DbContext"]
        SQL[("SQL Server LocalDB")]
        MQ[("MSMQ Private Queue")]
        Files[("Local File Storage")]
    end

    Browser -->|"HTTPS requests"| MVC
    MVC -->|"invokes"| Biz
    Biz -->|"CRUD via DbContext"| EF
    EF -->|"SQL operations"| SQL
    Biz -->|"enqueue notifications"| Notify
    Notify -->|"queue messages"| MQ
    Biz -->|"upload teaching images"| Files
```

### Technology Stack Summary

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| Presentation | ASP.NET MVC + Razor | MVC 5.2.9 / WebPages 3.2.9 | Server-rendered UI and request handling |
| Application | .NET Framework | 4.8 | Business processing in controllers and services |
| Data Access | Entity Framework Core | 3.1.32 | Relational persistence via `SchoolContext` |
| Messaging | System.Messaging (MSMQ) | .NET Framework built-in | Async notification queueing |
| Storage | SQL Server LocalDB | Configured in Web.config | Primary relational data store |

### Data Storage & External Services

The application persists core academic data in SQL Server LocalDB through EF Core. It additionally uses MSMQ as an internal asynchronous channel for notification messages and stores uploaded teaching material images on local disk under the application `Uploads/TeachingMaterials` path.

### Key Architectural Decisions

- Uses a monolithic ASP.NET MVC architecture with a single deployable web application.
- Centralizes persistence in one `DbContext` with Table-per-Hierarchy inheritance for `Person` (`Student` and `Instructor`).
- Adds asynchronous side effects for CRUD events by enqueueing notification messages to MSMQ.

## Component Relationships

```mermaid
flowchart LR
    subgraph Presentation
        StudentsCtrl["StudentsController"]
        CoursesCtrl["CoursesController"]
        InstructorsCtrl["InstructorsController"]
        DepartmentsCtrl["DepartmentsController"]
        NotificationsCtrl["NotificationsController"]
    end

    subgraph Business["Business Logic"]
        BaseCtrl["BaseController"]
        NotifSvc["NotificationService"]
        Pager["PaginatedList"]
    end

    subgraph DataAccess["Data Access"]
        CtxFactory["SchoolContextFactory"]
        DbCtx["SchoolContext"]
        Entities["Domain Entities"]
    end

    subgraph Infra["Infrastructure"]
        Routing["RouteConfig and Filters"]
        MSMQ["MSMQ Queue"]
        SqlDb["SQL Server LocalDB"]
        FileStore["TeachingMaterials Folder"]
    end

    StudentsCtrl -->|"inherits"| BaseCtrl
    CoursesCtrl -->|"inherits"| BaseCtrl
    InstructorsCtrl -->|"inherits"| BaseCtrl
    DepartmentsCtrl -->|"inherits"| BaseCtrl
    NotificationsCtrl -->|"inherits"| BaseCtrl
    BaseCtrl -->|"creates context"| CtxFactory
    CtxFactory -->|"builds options"| DbCtx
    StudentsCtrl -->|"query and save"| DbCtx
    CoursesCtrl -->|"query and save"| DbCtx
    InstructorsCtrl -->|"query and save"| DbCtx
    DepartmentsCtrl -->|"query and save"| DbCtx
    DbCtx -->|"maps"| Entities
    DbCtx -->|"persists"| SqlDb
    BaseCtrl -->|"uses"| NotifSvc
    NotifSvc -->|"send and receive"| MSMQ
    CoursesCtrl -->|"uploads and deletes files"| FileStore
    Routing -.->|"cross-cutting pipeline"| Presentation
    StudentsCtrl -->|"paging support"| Pager
```

### Component Inventory

| Component | Layer | Type | Responsibility |
|---|---|---|---|
| StudentsController | Presentation | MVC Controller | Student list/search/paging and CRUD lifecycle |
| CoursesController | Presentation | MVC Controller | Course CRUD and teaching material upload management |
| InstructorsController | Presentation | MVC Controller | Instructor assignment and course relationships |
| DepartmentsController | Presentation | MVC Controller | Department CRUD with optimistic concurrency handling |
| NotificationsController | Presentation | MVC Controller | Notification queue polling and mark-read endpoint |
| BaseController | Business Logic | Abstract Controller Base | Shared `SchoolContext` and notification dispatch helpers |
| NotificationService | Business Logic | Service | MSMQ send/receive wrapper for entity operation messages |
| SchoolContextFactory | Data Access | Factory | Builds EF Core `DbContextOptions` from web configuration |
| SchoolContext | Data Access | EF Core DbContext | Entity mapping, relationship configuration, and data persistence |
| RouteConfig / FilterConfig | Infrastructure | Configuration | MVC routing and global filter setup |
