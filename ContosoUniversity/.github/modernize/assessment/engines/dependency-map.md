# Dependency Map

This map summarizes declared external dependencies for ContosoUniversity (46 declared NuGet packages in `packages.config`) and groups them by modernization-relevant function.

## Dependencies

```mermaid
flowchart LR
    App["ContosoUniversity"]

    subgraph Web["Web Frameworks"]
        Mvc["Microsoft.AspNet.Mvc v5.2.9"]
        Razor["Microsoft.AspNet.Razor v3.2.9"]
        WebPages["Microsoft.AspNet.WebPages v3.2.9"]
        Optimization["Microsoft.AspNet.Web.Optimization v1.1.3"]
        JQuery["jQuery v3.7.1"]
        Bootstrap["bootstrap v5.3.3"]
    end

    subgraph Db["Database / ORM"]
        EFCore["Microsoft.EntityFrameworkCore v3.1.32"]
        EFSql["Microsoft.EntityFrameworkCore.SqlServer v3.1.32"]
        SqlClient["Microsoft.Data.SqlClient v2.1.4"]
    end

    subgraph Msg["Messaging"]
        MSMQ["System.Messaging (framework)"]
    end

    subgraph Cache["Caching"]
        MemCache["Microsoft.Extensions.Caching.Memory v3.1.32"]
        CacheAbstractions["Microsoft.Extensions.Caching.Abstractions v3.1.32"]
    end

    subgraph Log["Logging"]
        Logging["Microsoft.Extensions.Logging v3.1.32"]
        LoggingAbs["Microsoft.Extensions.Logging.Abstractions v3.1.32"]
    end

    subgraph Sec["Security"]
        MSAL["Microsoft.Identity.Client v4.21.1"]
    end

    subgraph Obs["Observability"]
        Diagnostic["System.Diagnostics.DiagnosticSource v4.7.1"]
    end

    subgraph Util["Utilities"]
        Json["Newtonsoft.Json v13.0.3"]
        DotNetCompiler["Microsoft.CodeDom.Providers.DotNetCompilerPlatform v2.0.1"]
        WebGrease["WebGrease v1.5.2"]
        Antlr["Antlr v3.4.1.9004"]
        NetStd["NETStandard.Library v2.0.3"]
    end

    App -->|"web"| Web
    App -->|"persistence"| Db
    App -->|"messaging"| Msg
    App -->|"caching"| Cache
    App -->|"logging"| Log
    App -->|"security"| Sec
    App -->|"observability"| Obs
    App -->|"utilities"| Util
    EFCore -.->|"provider"| EFSql
    EFSql -.->|"driver"| SqlClient
```

### Dependency Summary

| Category | Count | Key Libraries | Notes |
|---|---:|---|---|
| Web Frameworks | 6 | ASP.NET MVC 5.2.9, Razor 3.2.9, Bootstrap 5.3.3 | Legacy ASP.NET MVC stack on .NET Framework |
| Database / ORM | 3 | EF Core 3.1.32, SqlServer provider 3.1.32, SqlClient 2.1.4 | ORM and SQL provider are out of mainstream support |
| Messaging | 1 | System.Messaging | MSMQ dependency ties deployment to Windows features |
| Caching | 2 | Microsoft.Extensions.Caching.Memory 3.1.32 | Local in-process caching abstractions available |
| Logging | 2 | Microsoft.Extensions.Logging 3.1.32 | Basic logging abstractions only |
| Security | 1 | Microsoft.Identity.Client 4.21.1 | Identity client library present |
| Observability | 1 | DiagnosticSource 4.7.1 | Minimal diagnostic primitives |
| Utilities | 30 | Newtonsoft.Json 13.0.3, NETStandard.Library 2.0.3 | Large utility/transitive-support footprint from .NET Framework compatibility |

### Version & Compatibility Risks

The project targets .NET Framework 4.8 with ASP.NET MVC 5 and EF Core 3.1.x; EF Core 3.1 reached end of support and may require API and package updates before moving to supported modern .NET targets. System.Messaging usage also introduces migration risk because MSMQ is Windows-specific and not cloud-native by default.

### Notable Observations

- The dependency graph mixes legacy ASP.NET MVC packages with EF Core, creating a hybrid stack that can increase upgrade complexity.
- `System.Messaging` indicates queueing behavior is coupled to MSMQ and likely unavailable in Linux-based container environments without redesign.
- Utility and compatibility packages are numerous, suggesting potentially large transitive cleanup during modernization.

## Test Dependencies

| Framework | Version | Notes |
|---|---|---|
| None detected | N/A | No dedicated test package references found in `packages.config` |

Total test-scope dependencies: 0  
No test dependency declarations were detected in build/package files for this workspace.
