# Configuration & Externalized Settings Inventory

This inventory summarizes discovered configuration sources for the ContosoUniversity workspace, including web runtime settings, build configurations, and sensitive setting usage.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| `Web.config` | .NET web runtime config | `ContosoUniversity/Web.config` | Connection strings, appSettings, runtime binding redirects, HTTP/server limits |
| `Web.Debug.config` | Environment transform | `ContosoUniversity/Web.Debug.config` | Debug-time web configuration transforms |
| `Web.Release.config` | Environment transform | `ContosoUniversity/Web.Release.config` | Release-time web configuration transforms |
| `Views/Web.config` | Razor views config | `ContosoUniversity/Views/Web.config` | View engine namespace and runtime config |
| Project file | Build/runtime project settings | `ContosoUniversity/ContosoUniversity.csproj` | IIS Express settings, target framework, build properties |
| Package manifest | Dependency config | `ContosoUniversity/packages.config` | Declared NuGet package versions |

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| Debug | `Configuration=Debug` | Developer build with symbols and `DEBUG;TRACE` constants | Standard project references and web compilation debug mode |
| Release | `Configuration=Release` | Optimized build with `TRACE` constants | Same dependency set, optimized compilation |

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| Default (web runtime) | IIS/IIS Express application startup | `Web.config` | Default connection string and app settings |
| Debug transform | Build-time transform for debug publish/run | `Web.Debug.config` | Environment-specific overrides during debug deployment |
| Release transform | Build-time transform for release publish/run | `Web.Release.config` | Environment-specific overrides during release deployment |

## Properties Inventory

### ContosoUniversity

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `DefaultConnection` | `Data Source=(LocalDb)\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | Default | `Web.config` connectionStrings |
| `webpages:Version` | `3.0.0.0` | Default | `Web.config` appSettings |
| `webpages:Enabled` | `false` | Default | `Web.config` appSettings |
| `ClientValidationEnabled` | `true` | Default | `Web.config` appSettings |
| `UnobtrusiveJavaScriptEnabled` | `true` | Default | `Web.config` appSettings |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | Default | `Web.config` appSettings |
| `system.web/httpRuntime@maxRequestLength` | `10240` | Default | `Web.config` |
| `system.web/httpRuntime@executionTimeout` | `3600` | Default | `Web.config` |
| `system.webServer/security/requestFiltering/requestLimits@maxAllowedContentLength` | `10485760` | Default | `Web.config` |

## Startup Parameters & Resource Requirements

| Service | JVM/Runtime Options | Memory | Instance Count |
|---|---|---|---|
| ContosoUniversity web app | .NET Framework 4.8 runtime under IIS/IIS Express; no explicit command-line runtime flags found | Not explicitly configured in repository | 1 web application instance (default local setup) |

## Startup Dependency Chain

1. IIS/IIS Express starts the ContosoUniversity application and loads MVC route/filter/bundle configuration.  
2. `Application_Start` initializes `SchoolContext` and runs `DbInitializer.Initialize`, requiring SQL Server LocalDB availability before normal request handling.  
3. Notification operations require MSMQ private queue access at runtime; queue is created on first service use if missing.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage (masked) |
|---|---|---|
| `DefaultConnection` | Database connection string (integrated security) | Stored in `Web.config`; credentials not embedded, uses Windows integrated auth |
| `NotificationQueuePath` | Internal infrastructure endpoint | Stored in `Web.config` appSettings |

### Secrets Provisioning Workflow

Sensitive settings are file-based in `Web.config`, with no external secret manager integration detected. Database access relies on integrated Windows authentication instead of explicit passwords, so identity is provided by the host process account. Deployment-time transforms (`Web.Debug.config` / `Web.Release.config`) can override values per environment.

## Feature Flags

| Flag Name | Default | Controlled By |
|---|---|---|
| No dedicated feature flag framework detected | N/A | N/A |

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework target | 4.8 | `ContosoUniversity.csproj` |
| ASP.NET MVC | 5.2.9 | `packages.config` |
| Razor/WebPages | 3.2.9 | `packages.config` |
| Entity Framework Core | 3.1.32 | `packages.config` |
| SQL Client | 2.1.4 | `packages.config` |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| Bootstrap | 5.3.3 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |
