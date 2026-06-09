# Configuration & Externalized Settings Inventory

ContosoUniversity relies on a single `Web.config` XML file as its only configuration source; there are no environment-specific override files, external config servers, or secret stores — all settings including the database connection string are declared in plaintext.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|--------|------|--------------|-------|
| `Web.config` | XML application config | `ContosoUniversity/Web.config` | Primary and only configuration file; contains connection strings, app settings, HTTP runtime limits, and assembly binding redirects |
| `packages.config` | NuGet package manifest | `ContosoUniversity/packages.config` | Declares all NuGet dependency versions; not a runtime config source |
| `ContosoUniversity.csproj` | MSBuild project file | `ContosoUniversity/ContosoUniversity.csproj` | Build-time configuration; includes assembly references and build targets |
| `App_Start/RouteConfig.cs` | Code-based config | `ContosoUniversity/App_Start/RouteConfig.cs` | URL routing rules registered programmatically at startup |
| `App_Start/BundleConfig.cs` | Code-based config | `ContosoUniversity/App_Start/BundleConfig.cs` | Script/CSS bundle definitions registered programmatically at startup |
| `App_Start/FilterConfig.cs` | Code-based config | `ContosoUniversity/App_Start/FilterConfig.cs` | Global MVC filter registration (HandleErrorAttribute) |
| `Global.asax.cs` | Application startup | `ContosoUniversity/Global.asax.cs` | `Application_Start` wires together routing, bundles, filters, and EF Core database initialization |

No Spring Cloud Config server, Azure App Configuration, AWS AppConfig, Consul KV, HashiCorp Vault, or external configuration repository is used.

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---------|-----------|---------|--------------------------|
| Debug | Default (no flag needed); Visual Studio default | Development build; enables debug symbols, disables optimizations | `<compilation debug="true">` in Web.config; MSBuild `$(Configuration) == Debug` in .csproj |
| Release | Manual (`/p:Configuration=Release` MSBuild flag) | Production/packaging build; optimizations enabled | MSBuild `$(Configuration) == Release`; `<compilation debug="false">` should be set in Web.config for production deployments (currently hardcoded `debug="true"`) |

There are no Maven/Gradle multi-profile equivalents, no conditional compilation symbols defined, and no webpack/vite build configurations.

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---------|-----------------|-------------|---------------|
| Default (single environment) | Implicit — no environment variable or profile mechanism | `Web.config` only | No per-environment overrides available |

ASP.NET MVC 5 on .NET Framework does not support `ASPNETCORE_ENVIRONMENT` or `appsettings.{Environment}.json`. There is one static `Web.config` for all environments. No `Web.Debug.config` or `Web.Release.config` XDT transform files are present in the project.

## Properties Inventory

### ContosoUniversity — `Web.config` appSettings

| Property Key | Default Value | Profiles | Source |
|-------------|--------------|---------|--------|
| `webpages:Version` | `3.0.0.0` | All | `Web.config` appSettings |
| `webpages:Enabled` | `false` | All | `Web.config` appSettings |
| `ClientValidationEnabled` | `true` | All | `Web.config` appSettings |
| `UnobtrusiveJavaScriptEnabled` | `true` | All | `Web.config` appSettings |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | All | `Web.config` appSettings |

### ContosoUniversity — Connection Strings

| Key | Value | Profiles | Source |
|-----|-------|---------|--------|
| `DefaultConnection` | `Data Source=(LocalDb)\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | All | `Web.config` connectionStrings |

### ContosoUniversity — HTTP Runtime (`system.web` / `system.webServer`)

| Property | Value | Notes |
|---------|-------|-------|
| `compilation/@debug` | `true` | Hardcoded to debug; should be `false` in production |
| `compilation/@targetFramework` | `4.8` | |
| `httpRuntime/@targetFramework` | `4.8` | |
| `httpRuntime/@maxRequestLength` | `10240` (KB = 10 MB) | Limits HTTP request body size |
| `httpRuntime/@executionTimeout` | `3600` (seconds = 1 hour) | Per-request execution timeout |
| `requestLimits/@maxAllowedContentLength` | `10485760` (bytes = 10 MB) | IIS-level request size limit (must match `maxRequestLength`) |

## Startup Parameters & Resource Requirements

| Service | Runtime Options | Memory | CPU | Instance Count | Notes |
|---------|----------------|--------|-----|----------------|-------|
| ContosoUniversity (IIS Express) | .NET Framework 4.8 CLR; no explicit JVM-equivalent heap settings | Not configured | Not configured | 1 (IIS Express single instance for dev) | No containerization, no Kubernetes, no Docker Compose; resource limits are governed by IIS and the OS |

No JVM heap settings, `-D` system properties, `ASPNETCORE_ENVIRONMENT` overrides, Docker resource limits, or Kubernetes resource requests/limits are configured.

## Startup Dependency Chain

The application has no external services to wait for beyond the local SQL Server LocalDB instance. The startup sequence is:

1. **IIS / IIS Express** loads the application pool and starts the .NET Framework CLR.
2. **`Application_Start()`** (`Global.asax.cs`) runs synchronously:
   - `AreaRegistration.RegisterAllAreas()`
   - `FilterConfig.RegisterGlobalFilters()`
   - `RouteConfig.RegisterRoutes()`
   - `BundleConfig.RegisterBundles()`
   - `InitializeDatabase()` → reads `DefaultConnection` from `Web.config` → creates `SchoolContext` → calls `DbInitializer.Initialize()` → seeds data if empty
3. Application begins serving HTTP requests.

No health-check wait mechanisms (dockerize, Kubernetes readiness probes, Spring Cloud Config retry) are configured. If SQL Server LocalDB is unavailable at startup, `Application_Start` will throw an unhandled exception and the application will fail to start. There is no retry logic or fallback.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage |
|-----------------|------|---------|
| `DefaultConnection` connection string | SQL Server connection string | Plaintext in `Web.config` (uses Windows Integrated Security — no password in the string) |
| `NotificationQueuePath` | MSMQ queue path | Plaintext in `Web.config` appSettings — not a credential, but an infrastructure path |

The database connection uses Windows Integrated Security (`Integrated Security=True`), so there is no database password in the configuration. However, the full connection string (including server and database name) is stored in plaintext in `Web.config` with no encryption.

### Secrets Provisioning Workflow

No secrets management workflow is implemented. There is no HashiCorp Vault, Azure KeyVault, AWS Secrets Manager, DPAPI encryption, or Jasypt integration. The sole sensitive configuration item (the database connection string) is stored in plaintext in `Web.config`. For cloud deployment, this would need to be replaced with environment-specific configuration (e.g., Azure App Configuration, environment variable injection at the IIS/App Service level, or ASP.NET Core's `IConfiguration` with secrets management).

## Feature Flags

No feature flag framework is configured. There are no `@ConditionalOnProperty` equivalents, LaunchDarkly integration, .NET `Microsoft.FeatureManagement` references, or custom toggle patterns in the codebase. The `Microsoft.Identity.Client` (MSAL) library is declared as a dependency but authentication is disabled by a commented-out line in `FilterConfig.cs` — this is the closest thing to a feature toggle, but it is a static code change rather than a runtime flag.

| Flag Name | Default | Controlled By |
|-----------|---------|--------------|
| Authentication/Authorization | Disabled (commented out) | Code change in `FilterConfig.cs` — not a runtime flag |

## Framework & Runtime Versions

| Component | Version | Source |
|-----------|---------|--------|
| .NET Framework | 4.8 | `ContosoUniversity.csproj` `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` |
| ASP.NET MVC | 5.2.9 | `packages.config` `Microsoft.AspNet.Mvc` |
| ASP.NET Razor | 3.2.9 | `packages.config` `Microsoft.AspNet.Razor` |
| ASP.NET WebPages | 3.2.9 | `packages.config` `Microsoft.AspNet.WebPages` |
| Entity Framework Core | 3.1.32 | `packages.config` `Microsoft.EntityFrameworkCore` |
| EF Core SQL Server Provider | 3.1.32 | `packages.config` `Microsoft.EntityFrameworkCore.SqlServer` |
| Microsoft.Data.SqlClient | 2.1.4 | `packages.config` |
| Microsoft.Extensions.* | 3.1.32 | `packages.config` (DI, Config, Logging, Caching) |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| Microsoft.Identity.Client (MSAL) | 4.21.1 | `packages.config` |
| Bootstrap | 5.3.3 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |
| jQuery.Validation | 1.21.0 | `packages.config` |
| Modernizr | 2.6.2 | `packages.config` |
| WebGrease | 1.5.2 | `packages.config` |
| System.Web.Optimization | 1.1.3 | `packages.config` `Microsoft.AspNet.Web.Optimization` |
| Roslyn Compiler Platform | 2.0.1 | `packages.config` `Microsoft.CodeDom.Providers.DotNetCompilerPlatform` |
| MSBuild | 15.0 (ToolsVersion) | `ContosoUniversity.csproj` `ToolsVersion="15.0"` |
| IIS Express | Local dev server | Visual Studio launch profile |
| SQL Server LocalDB | MSSQLLocalDB (version from SQL Server install) | `Web.config` connection string |
| MSMQ | Windows OS component | `System.Messaging` (BCL — no NuGet version) |
