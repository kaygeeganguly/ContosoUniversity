# Configuration & Externalized Settings Inventory

This project uses a small set of XML-based configuration sources with environment-specific behavior primarily driven by build configuration (Debug/Release) and IIS hosting settings. Configuration is local-file-centric, with no external config server or secret vault integration detected.

## Configuration Sources

| Source | Type | Path/Location | Notes |
| --- | --- | --- | --- |
| Main web runtime config | XML configuration | `ContosoUniversity/Web.config` | Defines connection string, app settings, runtime settings, assembly redirects, request limits |
| Razor view config | XML configuration | `ContosoUniversity/Views/Web.config` | View engine namespaces, Razor host setup, handler restrictions |
| Build/project config | MSBuild project | `ContosoUniversity/ContosoUniversity.csproj` | Build configurations, target framework, references, web application targets import |
| Package manifest | NuGet packages file | `ContosoUniversity/packages.config` | Declares package versions used by runtime and build |
| IIS Express project settings | Project extension block | `ContosoUniversity/ContosoUniversity.csproj` | Contains local IIS Express URL and auth flags |

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
| --- | --- | --- | --- |
| Debug | Default/local build configuration | Development-time build with symbols and disabled optimization | `DefineConstants=DEBUG;TRACE`, full debug symbols |
| Release | Explicit `Configuration=Release` | Optimized production-style build output | `DefineConstants=TRACE`, optimized compilation |

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
| --- | --- | --- | --- |
| Default web runtime | IIS/IIS Express app startup | `Web.config`, `Views/Web.config` | SQL connection string, MVC/Razor app settings, request filtering, queue path |
| IIS Express local profile | Visual Studio/IIS Express launch | `ContosoUniversity.csproj` project extension metadata | Local HTTPS URL (`https://localhost:44300/`), Windows auth enabled, anonymous auth disabled |

## Properties Inventory

### ContosoUniversity.Web

| Property Key | Default | Profiles | Source |
| --- | --- | --- | --- |
| `connectionStrings:DefaultConnection` | `Data Source=(LocalDb)\\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | Default runtime | `Web.config` |
| `webpages:Version` | `3.0.0.0` | Default runtime | `Web.config`, `Views/Web.config` |
| `webpages:Enabled` | `false` | Default runtime | `Web.config`, `Views/Web.config` |
| `ClientValidationEnabled` | `true` | Default runtime | `Web.config` |
| `UnobtrusiveJavaScriptEnabled` | `true` | Default runtime | `Web.config` |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | Default runtime | `Web.config` |
| `system.web:compilation@debug` | `true` | Default runtime | `Web.config` |
| `system.web:httpRuntime@targetFramework` | `4.8` | Default runtime | `Web.config` |
| `system.web:httpRuntime@maxRequestLength` | `10240` | Default runtime | `Web.config` |
| `system.web:httpRuntime@executionTimeout` | `3600` | Default runtime | `Web.config` |
| `system.webServer/requestFiltering/requestLimits@maxAllowedContentLength` | `10485760` | Default runtime | `Web.config` |

### Build and project properties

| Property Key | Default | Profiles | Source |
| --- | --- | --- | --- |
| `TargetFrameworkVersion` | `v4.8` | Debug, Release | `ContosoUniversity.csproj` |
| `VisualStudioVersion` | `10.0` if undefined | Debug, Release | `ContosoUniversity.csproj` |
| `VSToolsPath` | `$(MSBuildExtensionsPath32)\Microsoft\VisualStudio\v$(VisualStudioVersion)` | Debug, Release | `ContosoUniversity.csproj` |
| `OutputPath` | `bin\` | Debug, Release | `ContosoUniversity.csproj` |
| `DefineConstants` | `DEBUG;TRACE` (Debug), `TRACE` (Release) | Build-specific | `ContosoUniversity.csproj` |

## Startup Parameters & Resource Requirements

| Service | JVM/Runtime Options | Memory | Instance Count |
| --- | --- | --- | --- |
| ContosoUniversity.Web | No explicit JVM/runtime CLI flags detected; ASP.NET runtime options set via `Web.config` (`executionTimeout`, request limits) | No explicit memory allocation settings detected | Single local web app instance implied |

## Startup Dependency Chain

1. `MvcApplication.Application_Start` initializes MVC filters, routes, and bundles.
2. Application startup then invokes database initialization (`DbInitializer.Initialize`) using `SchoolContext`.
3. During runtime, notification operations lazily depend on MSMQ availability; `NotificationService` creates queue if missing.

No orchestrator-level startup wait mechanisms (Docker Compose health checks, Kubernetes probes, or config server bootstrap ordering) were detected.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage (masked) |
| --- | --- | --- |
| `connectionStrings:DefaultConnection` | Database connection string | `Web.config` (integrated security; no password present) |
| `NotificationQueuePath` | Messaging endpoint path | `Web.config` (non-secret operational setting) |

### Secrets Provisioning Workflow

Sensitive configuration is provisioned through local XML configuration files checked with the application. No managed secret store integration (Key Vault, Vault, Secrets Manager) or CI-time secret injection workflow was detected. The current configuration relies on Windows integrated authentication for database access and local machine queue setup for notifications.

## Feature Flags

| Flag Name | Default | Controlled By |
| --- | --- | --- |
| No explicit feature flags detected | N/A | N/A |

## Framework & Runtime Versions

| Component | Version | Source |
| --- | --- | --- |
| .NET Framework target | 4.8 | `ContosoUniversity.csproj` |
| ASP.NET MVC | 5.2.9 | `packages.config` and assembly references |
| ASP.NET Razor/WebPages | 3.2.9 | `packages.config`, `Views/Web.config` |
| Entity Framework Core | 3.1.32 | `packages.config` |
| SQL client library | 2.1.4 (`Microsoft.Data.SqlClient`) | `packages.config` |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| jQuery | 3.7.1 declared package (3.4.1 scripts present) | `packages.config`, `Scripts/*` |
| Bootstrap | 5.3.3 declared package | `packages.config` |
| MSBuild ToolsVersion | 15.0 project schema | `ContosoUniversity.csproj` |
