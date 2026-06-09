# Dependency Map

This document maps declared external dependencies for ContosoUniversity from `packages.config` and project references. The project declares 45 package dependencies.

## Dependencies

```mermaid
flowchart LR
    App["ContosoUniversity"]

    subgraph Web["Web Frameworks"]
        AspMvc["Microsoft.AspNet.Mvc 5.2.9"]
        Razor["Microsoft.AspNet.Razor 3.2.9"]
        WebPages["Microsoft.AspNet.WebPages 3.2.9"]
        WebOpt["Microsoft.AspNet.Web.Optimization 1.1.3"]
    end

    subgraph DB["Database and ORM"]
        EfCore["Microsoft.EntityFrameworkCore 3.1.32"]
        EfSql["Microsoft.EntityFrameworkCore.SqlServer 3.1.32"]
        SqlClient["Microsoft.Data.SqlClient 2.1.4"]
    end

    subgraph Msg["Messaging"]
        MsmqRef["System.Messaging framework"]
    end

    subgraph Cache["Caching"]
        MemCache["Microsoft.Extensions.Caching.Memory 3.1.32"]
        CacheAbs["Microsoft.Extensions.Caching.Abstractions 3.1.32"]
    end

    subgraph Log["Logging"]
        LogAbs["Microsoft.Extensions.Logging.Abstractions 3.1.32"]
        LogCore["Microsoft.Extensions.Logging 3.1.32"]
        DiagSrc["System.Diagnostics.DiagnosticSource 4.7.1"]
    end

    subgraph Sec["Security"]
        Msal["Microsoft.Identity.Client 4.21.1"]
        JqUnob["Microsoft.jQuery.Unobtrusive.Validation 4.0.0"]
        JqVal["jQuery.Validation 1.21.0"]
    end

    subgraph Obs["Observability"]
        DebugTrace["System.Diagnostics and Trace APIs"]
    end

    subgraph Util["Utilities"]
        Json["Newtonsoft.Json 13.0.3"]
        Di["Microsoft.Extensions.DependencyInjection 3.1.32"]
        Config["Microsoft.Extensions.Configuration 3.1.32"]
        Frontend["bootstrap 5.3.3 and jQuery 3.7.1"]
        UtilsAgg["25 additional utility/runtime packages"]
    end

    App -->|"web"| Web
    App -->|"persistence"| DB
    App -->|"messaging"| Msg
    App -->|"caching"| Cache
    App -->|"logging"| Log
    App -->|"security"| Sec
    App -->|"observability"| Obs
    App -->|"utilities"| Util

    EfCore -.->|"provider"| EfSql
    EfSql -.->|"driver"| SqlClient
    LogCore -.->|"abstractions"| LogAbs
```

### Dependency Summary

| Category | Count | Key Libraries | Notes |
| --- | --- | --- | --- |
| Web Frameworks | 4 | Microsoft.AspNet.Mvc 5.2.9, Microsoft.AspNet.Razor 3.2.9 | Classic ASP.NET MVC 5 stack on .NET Framework |
| Database and ORM | 6 | EntityFrameworkCore 3.1.32, SqlServer provider 3.1.32, SqlClient 2.1.4 | EF Core 3.1 is out of support and tied to legacy runtime |
| Messaging | 1 | System.Messaging (framework) | Uses MSMQ APIs from .NET Framework |
| Caching | 2 | Microsoft.Extensions.Caching.Memory 3.1.32 | Local in-memory caching primitives |
| Logging | 3 | Microsoft.Extensions.Logging 3.1.32, DiagnosticSource 4.7.1 | Mixed logging abstractions and framework tracing |
| Security | 3 | Microsoft.Identity.Client 4.21.1, jQuery validation libs | Client/server validation and identity client usage |
| Observability | 1 | System.Diagnostics tracing APIs | Trace-based diagnostics in controllers/services |
| Utilities | 25 | Newtonsoft.Json 13.0.3, configuration/DI/runtime support packages | Includes compiler, primitives, and front-end support libs |

### Version and Compatibility Risks

The application depends on .NET Framework 4.8 and ASP.NET MVC 5.2.9, which are mature but not aligned with modern .NET hosting models. Entity Framework Core 3.1 and the related Microsoft.Extensions 3.1 packages are out of support, creating modernization pressure for runtime and API upgrades. MSMQ via System.Messaging is Windows-specific and requires redesign when moving to cloud-native messaging platforms.

### Notable Observations

- Both ASP.NET MVC 5 packages and EF Core 3.1 packages are combined in a .NET Framework project, increasing migration complexity.
- Front-end package versions in `packages.config` (jQuery 3.7.1, Bootstrap 5.3.3) differ from checked-in script assets (jQuery 3.4.1), indicating potential asset drift.
- Utility/runtime packages are numerous; several support EF Core 3.1 and will likely consolidate after target framework upgrade.
- Messaging relies on `System.Messaging` and private MSMQ queues, a portability concern for Linux-based hosting.

## Test Dependencies

| Framework | Version | Notes |
| --- | --- | --- |
| None detected | N/A | No test-scoped dependencies were declared in build/package manifests |

Total test-scope dependencies: 0
No test dependencies were detected in the repository build/package files, indicating tests may be absent or external to this project.
