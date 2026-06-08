# Dependency Map

This map summarizes declared package dependencies for ContosoUniversity and groups them by functional purpose.

## Dependencies

```mermaid
flowchart LR
    App["ContosoUniversity"]

    subgraph Web["Web Frameworks"]
        AspMvc["Microsoft.AspNet.Mvc 5.2.9"]
        Razor["Microsoft.AspNet.Razor 3.2.9"]
        WebPages["Microsoft.AspNet.WebPages 3.2.9"]
        Bootstrap["bootstrap 5.3.3"]
        JQuery["jQuery 3.7.1"]
    end
    subgraph Db["Database and ORM"]
        EfCore["Microsoft.EntityFrameworkCore 3.1.32"]
        EfSql["Microsoft.EntityFrameworkCore.SqlServer 3.1.32"]
        SqlClient["Microsoft.Data.SqlClient 2.1.4"]
    end
    subgraph Messaging["Messaging"]
        Msmq["System.Messaging .NET Framework"]
    end
    subgraph Cache["Caching"]
        MemCache["Microsoft.Extensions.Caching.Memory 3.1.32"]
    end
    subgraph Log["Logging"]
        ExtLog["Microsoft.Extensions.Logging 3.1.32"]
    end
    subgraph Security["Security"]
        Msal["Microsoft.Identity.Client 4.21.1"]
    end
    subgraph Util["Utilities"]
        Json["Newtonsoft.Json 13.0.3"]
        Opt["Microsoft.AspNet.Web.Optimization 1.1.3"]
        WebGrease["WebGrease 1.5.2"]
    end

    App -->|"web"| Web
    App -->|"persistence"| Db
    App -->|"messaging"| Messaging
    App -->|"caching"| Cache
    App -->|"logging"| Log
    App -->|"security"| Security
    App -->|"utilities"| Util
```

### Dependency Summary

| Category | Count | Key Libraries | Notes |
|---|---|---|---|
| Web Frameworks | 5 | Microsoft.AspNet.Mvc, Razor, bootstrap | ASP.NET MVC 5 server-rendered stack |
| Database / ORM | 3 | EF Core, EF Core SqlServer, SqlClient | EF Core 3.1 on .NET Framework |
| Messaging | 1 | System.Messaging | MSMQ-based local queue notifications |
| Caching | 1 | Microsoft.Extensions.Caching.Memory | Memory cache package referenced |
| Logging | 1 | Microsoft.Extensions.Logging | Logging abstractions package referenced |
| Security | 1 | Microsoft.Identity.Client | Identity client dependency present |
| Utilities | 3 | Newtonsoft.Json, Web.Optimization, WebGrease | JSON and asset bundling support |

### Version & Compatibility Risks

The project targets .NET Framework 4.8 with ASP.NET MVC 5 and EF Core 3.1. Both MVC 5 and EF Core 3.1 are older stacks compared with current .NET LTS versions, so package compatibility and framework modernization effort should be expected during migration planning.

### Notable Observations

- The solution mixes classic ASP.NET MVC with newer Microsoft.Extensions packages.
- Messaging relies on MSMQ (`System.Messaging`), which is Windows-specific and may require redesign for cloud portability.
- Client libraries are modernized (Bootstrap 5.3.3 and jQuery 3.7.1), while server framework remains legacy.

## Test Dependencies

| Framework | Version | Notes |
|---|---|---|
| None detected | N/A | No test-scoped packages found in `packages.config` |

Total test-scope dependencies: 0
No dedicated test infrastructure was detected in this repository snapshot.

