# Configuration & Externalized Settings Inventory

The project uses a compact configuration surface centered on `Web.config`, package metadata, and runtime defaults in code for database and queue connectivity.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| Web.config | XML app/runtime config | `ContosoUniversity/Web.config` | Connection string, appSettings, runtime binding redirects |
| Views Web.config | Razor view config | `ContosoUniversity/Views/Web.config` | View-engine/runtime behavior for Razor |
| packages.config | NuGet dependency manifest | `ContosoUniversity/packages.config` | Declared package versions |
| ContosoUniversity.csproj | MSBuild project config | `ContosoUniversity/ContosoUniversity.csproj` | Build configs, framework target, package references |
| RouteConfig/BundleConfig | Code-based runtime setup | `App_Start/*.cs` | Route pattern and bundle registration |

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| Debug | Default local build | Debugging with symbols and non-optimized output | `DefineConstants=DEBUG;TRACE` |
| Release | Explicit `Configuration=Release` | Optimized production build output | `DefineConstants=TRACE` |

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| Default | IIS/IIS Express startup | `Web.config` | SQL LocalDB connection, queue path, HTTP runtime limits |

## Properties Inventory

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `connectionStrings:DefaultConnection` | LocalDB connection string | Default | Web.config |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | Default | Web.config appSettings |
| `webpages:Version` | `3.0.0.0` | Default | Web.config appSettings |
| `webpages:Enabled` | `false` | Default | Web.config appSettings |
| `ClientValidationEnabled` | `true` | Default | Web.config appSettings |
| `UnobtrusiveJavaScriptEnabled` | `true` | Default | Web.config appSettings |
| `system.web/compilation@debug` | `true` | Default | Web.config |
| `system.web/httpRuntime@maxRequestLength` | `10240` | Default | Web.config |
| `system.webServer/requestLimits@maxAllowedContentLength` | `10485760` | Default | Web.config |

## Startup Parameters & Resource Requirements

| Service | JVM/Runtime Options | Memory | Instance Count |
|---|---|---|---|
| ContosoUniversity | ASP.NET on .NET Framework 4.8, no explicit startup flags | Not explicitly configured | Single web app instance (implicit) |

## Startup Dependency Chain

1. IIS/IIS Express starts ASP.NET application.
2. `Application_Start` registers routes/filters/bundles and invokes database initialization.
3. `DbInitializer.Initialize` seeds SQL data if required.
4. Request handlers instantiate `NotificationService` when controllers need queue operations.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage (masked) |
|---|---|---|
| `connectionStrings:DefaultConnection` | Database connection string | Web.config (`[MASKED]`) |
| `NotificationQueuePath` | Infrastructure endpoint | Web.config |

### Secrets Provisioning Workflow

Sensitive values are currently configured as static XML settings loaded at runtime by `ConfigurationManager`. No external secret manager or managed identity integration was found; deployment must provide secured Web.config transforms or environment-level protections outside this repository.

## Feature Flags

| Flag Name | Default | Controlled By |
|---|---|---|
| No explicit feature flags detected | n/a | n/a |

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework | 4.8 | `ContosoUniversity.csproj` |
| ASP.NET MVC | 5.2.9 | `packages.config` |
| EF Core | 3.1.32 | `packages.config` |
| Microsoft.Data.SqlClient | 2.1.4 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |
| bootstrap | 5.3.3 | `packages.config` |
