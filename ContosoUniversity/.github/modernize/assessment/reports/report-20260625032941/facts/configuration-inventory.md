# Configuration & Externalized Settings Inventory

ContosoUniversity uses a single XML-based `Web.config` as its only configuration source, with no environment-specific overrides, external config server, secrets management, or feature flag framework.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| Web.config | XML (ASP.NET) | `ContosoUniversity/Web.config` | Primary config — connection strings, app settings, HTTP runtime, assembly binding redirects |
| Views/Web.config | XML (ASP.NET) | `ContosoUniversity/Views/Web.config` | Razor view engine configuration; restricts direct access to Views directory |
| packages.config | XML (NuGet) | `ContosoUniversity/packages.config` | NuGet package manifest (legacy packages.config format, not PackageReference) |
| Global.asax.cs | C# startup | `ContosoUniversity/Global.asax.cs` | Application startup — registers routes, filters, bundles, and seeds DB |
| App_Start/*.cs | C# configuration | `ContosoUniversity/App_Start/` | RouteConfig, BundleConfig, FilterConfig — configuration-as-code |

No environment-specific config files (`Web.Debug.config`, `Web.Release.config` transforms beyond defaults), `appsettings.json`, `launchSettings.json`, Spring Cloud Config, Azure App Configuration, HashiCorp Vault, or external secrets store references are present.

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| Debug | Visual Studio / `msbuild /p:Configuration=Debug` | Development build — full PDB symbols, debug output | `<compilation debug="true">` in Web.config; no optimization |
| Release | `msbuild /p:Configuration=Release` | Production build — PDB-only, optimized | `<compilation debug="false">` (transform needed); bundle minification |

No Maven/Gradle multi-module profiles, conditional compilation symbols (`#if RELEASE`), or NuGet Central Package Management (Directory.Packages.props) are configured. The project uses the legacy packages.config NuGet workflow.

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| Default (single profile) | Implicit — no `ASPNETCORE_ENVIRONMENT` or `web.config` transforms active | `Web.config` | No overrides — identical config for all environments |

The application has no runtime profile system. There is no `Web.Development.config` or `Web.Production.config` transform, no `appsettings.{Environment}.json`, and no `ASPNETCORE_ENVIRONMENT` variable (not applicable to ASP.NET MVC 5 / System.Web). All environments use the same `Web.config` with no per-environment differentiation.

## Properties Inventory

### ContosoUniversity — Web.config Properties

| Property Key | Default Value | Profile | Source |
|---|---|---|---|
| `connectionStrings/DefaultConnection` | `Data Source=(LocalDb)\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | All | Web.config `<connectionStrings>` |
| `appSettings/webpages:Version` | `3.0.0.0` | All | Web.config `<appSettings>` |
| `appSettings/webpages:Enabled` | `false` | All | Web.config `<appSettings>` |
| `appSettings/ClientValidationEnabled` | `true` | All | Web.config `<appSettings>` |
| `appSettings/UnobtrusiveJavaScriptEnabled` | `true` | All | Web.config `<appSettings>` |
| `appSettings/NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | All | Web.config `<appSettings>` |
| `system.web/compilation[@debug]` | `true` | All | Web.config (should be `false` in Release) |
| `system.web/compilation[@targetFramework]` | `4.8` | All | Web.config |
| `system.web/httpRuntime[@targetFramework]` | `4.8` | All | Web.config |
| `system.web/httpRuntime[@maxRequestLength]` | `10240` (KB = 10 MB) | All | Web.config |
| `system.web/httpRuntime[@executionTimeout]` | `3600` (seconds = 1 hour) | All | Web.config |
| `system.webServer/requestFiltering/requestLimits[@maxAllowedContentLength]` | `10485760` (bytes = 10 MB) | All | Web.config |

### SchoolContextFactory (runtime-constructed)

| Property | Value | Source |
|---|---|---|
| EF Core connection string | Read from `ConfigurationManager.ConnectionStrings["DefaultConnection"]` | Web.config |
| EF Core provider | `UseSqlServer(connectionString)` | Hard-coded in `SchoolContextFactory.cs` and `Global.asax.cs` |
| Schema init | `EnsureCreated()` | Hard-coded in `DbInitializer.Initialize()` |

## Startup Parameters & Resource Requirements

| Service | Runtime Options | Memory Limit | Instance Count | Notes |
|---|---|---|---|---|
| ContosoUniversity | IIS / IISExpress (no JVM; .NET Framework CLR managed automatically) | Not configured | 1 (single IIS app pool) | No Docker, Kubernetes, or cloud deployment configuration; `executionTimeout=3600s` is notably long |

No Docker Compose services, Kubernetes manifests, Helm charts, JVM heap settings, or cloud deployment sizing are present.

## Startup Dependency Chain

1. **IIS Application Pool** starts the .NET Framework CLR process
2. **`Global.asax.cs` Application_Start** fires:
   - `AreaRegistration.RegisterAllAreas()`
   - `FilterConfig.RegisterGlobalFilters(...)` — registers `HandleErrorAttribute`
   - `RouteConfig.RegisterRoutes(...)` — registers default `{controller}/{action}/{id}` route
   - `BundleConfig.RegisterBundles(...)` — registers JS/CSS bundles
   - `InitializeDatabase()` — creates `SchoolContext`, calls `EnsureCreated()`, then `DbInitializer.Initialize()`
3. **SQL Server (LocalDB)** must be accessible when `InitializeDatabase()` runs; there is no retry, wait, or health-check mechanism — a startup failure here will crash the application pool without a friendly error

No `dockerize` wait-for-TCP, Kubernetes readiness probes, Spring Cloud Config retry, or `depends_on` health checks are configured. The application has a hard dependency on SQL Server availability at startup with no resilience.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage |
|---|---|---|
| `connectionStrings/DefaultConnection` | SQL Server connection string (Integrated Security — no password) | Web.config plaintext |
| `appSettings/NotificationQueuePath` | MSMQ queue path | Web.config plaintext |

The connection string uses **Windows Integrated Security** (no embedded password), which avoids a database credential secret in the config file. However, the connection string itself is stored in plaintext in `Web.config` and is committed to source control.

### Secrets Provisioning Workflow

No secrets management workflow is implemented. The single connection string uses Windows Integrated Security, so no credential rotation, Key Vault binding, environment variable injection, or secrets manager integration is configured. For production deployments, the `Web.config` connection string must be manually replaced or overridden via an IIS application-level connection string (not documented). There is no DPAPI encryption, `web.config` `<configProtectedData>` section, Azure Key Vault reference, or CI/CD secrets injection pipeline.

## Feature Flags

No feature flag framework is configured. There are no LaunchDarkly, Unleash, .NET `Microsoft.FeatureManagement`, `@ConditionalOnProperty`, or custom boolean `appSettings` toggle patterns present. The `webpages:Enabled = false` setting disables ASP.NET Web Pages (a framework opt-out, not a feature flag).

| Flag Name | Default | Controlled By | Purpose |
|---|---|---|---|
| `webpages:Enabled` | `false` | Web.config | Disables ASP.NET Web Pages framework (not a business feature flag) |
| `ClientValidationEnabled` | `true` | Web.config | Enables ASP.NET MVC client-side validation helpers |
| `UnobtrusiveJavaScriptEnabled` | `true` | Web.config | Enables unobtrusive jQuery validation integration |

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework | 4.8 | Web.config `targetFramework`, csproj `TargetFrameworkVersion` |
| ASP.NET MVC | 5.2.9 | packages.config |
| ASP.NET Razor | 3.2.9 | packages.config |
| ASP.NET WebPages | 3.2.9 | packages.config |
| Entity Framework Core | 3.1.32 | packages.config |
| EF Core SQL Server provider | 3.1.32 | packages.config |
| Microsoft.Data.SqlClient | 2.1.4 | packages.config |
| Newtonsoft.Json | 13.0.3 | packages.config |
| Bootstrap | 5.3.3 | packages.config |
| jQuery | 3.7.1 | packages.config |
| Microsoft.Identity.Client (MSAL) | 4.21.1 | packages.config |
| NuGet format | packages.config (legacy) | packages.config file present; no Directory.Packages.props |
| Build tool | MSBuild (Visual Studio 2017+ toolset, ToolsVersion 15.0) | ContosoUniversity.csproj |
| IIS Express | Dev only | csproj `UseIISExpress=true` |
