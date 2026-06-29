# Configuration & Externalized Settings Inventory

ContosoUniversity uses a single `Web.config`-based configuration model with no environment profiles, no secret store integrations, and no external configuration server — all settings are statically declared in XML configuration files.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| Web.config | XML — primary configuration | `ContosoUniversity/Web.config` | Contains connection strings, appSettings, HTTP runtime settings, assembly binding redirects |
| Views/Web.config | XML — Razor view configuration | `ContosoUniversity/Views/Web.config` | Restricts direct HTTP access to `.cshtml` view files; configures Razor host and MVC view page namespaces |
| packages.config | XML — NuGet package manifest | `ContosoUniversity/packages.config` | Declares all NuGet package dependencies with exact versions |
| Global.asax.cs | Code — application startup | `ContosoUniversity/Global.asax.cs` | Registers routes, filters, bundles, and initialises the database on application start |
| App_Start/*.cs | Code — startup configuration | `ContosoUniversity/App_Start/` | RouteConfig, FilterConfig, BundleConfig registered from Global.asax |

No `appsettings.json`, `launchSettings.json`, `.env`, Docker Compose environment sections, Kubernetes ConfigMaps, Azure App Configuration, or any secret store references were found.

## Build Profiles

| Profile | Activation | Purpose | Key Properties/Plugins |
|---|---|---|---|
| Debug | Default (IDE/`dotnet build`) | Development build with debug symbols; `compilation debug="true"` in Web.config | `debug="true"` in `<compilation>` |
| Release | Manual (`/p:Configuration=Release` or Publish) | Optimised publish output; debug symbols disabled | Standard MSBuild Release configuration |

No custom MSBuild property groups, conditional compilation symbols, or feature-specific build profiles are defined in the `.csproj`.

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| Single (no profiles) | N/A | `Web.config` | There are no environment-specific configuration file overrides |

The application has no concept of runtime profiles (`Development`, `Staging`, `Production`). All configuration is read from a single `Web.config`. Switching environments (e.g., changing the database connection string for production) requires manually editing `Web.config` before deployment. `ASPNETCORE_ENVIRONMENT` is not used — this is a classic ASP.NET application, not ASP.NET Core.

## Properties Inventory

### ContosoUniversity — Connection Strings (`Web.config`)

| Property Key | Value | Source |
|---|---|---|
| `DefaultConnection` | `Data Source=(LocalDb)\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | `Web.config` `<connectionStrings>` |

### ContosoUniversity — Application Settings (`Web.config`)

| Property Key | Value | Source |
|---|---|---|
| `webpages:Version` | `3.0.0.0` | `Web.config` `<appSettings>` |
| `webpages:Enabled` | `false` | `Web.config` `<appSettings>` |
| `ClientValidationEnabled` | `true` | `Web.config` `<appSettings>` |
| `UnobtrusiveJavaScriptEnabled` | `true` | `Web.config` `<appSettings>` |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | `Web.config` `<appSettings>` |

### ContosoUniversity — HTTP Runtime Settings (`Web.config`)

| Property Key | Value | Source |
|---|---|---|
| `targetFramework` (compilation) | `4.8` | `Web.config` `<system.web>/<compilation>` |
| `targetFramework` (httpRuntime) | `4.8` | `Web.config` `<system.web>/<httpRuntime>` |
| `maxRequestLength` | `10240` (KB = 10 MB) | `Web.config` `<httpRuntime>` |
| `executionTimeout` | `3600` (seconds = 1 hour) | `Web.config` `<httpRuntime>` |
| `maxAllowedContentLength` | `10485760` (bytes = 10 MB) | `Web.config` `<system.webServer>/<requestFiltering>` |

## Startup Parameters & Resource Requirements

| Service | Runtime Options | Memory | Instance Count |
|---|---|---|---|
| ContosoUniversity | Hosted by IIS / IIS Express; no explicit JVM or CLR heap settings configured | Not specified — default IIS application pool memory limits | 1 (no scaling configuration) |

No container configuration (`Dockerfile`, Docker Compose, Kubernetes manifests) is present. The application runs as a standard IIS application pool. No `web.config` `<processModel>` memory limits or CPU affinity settings are configured.

## Startup Dependency Chain

1. **IIS Application Pool starts** → `.NET Framework 4.8` CLR loaded
2. **`Global.asax Application_Start`** fires:
   - `AreaRegistration.RegisterAllAreas()`
   - `FilterConfig.RegisterGlobalFilters()` — registers `HandleErrorAttribute`
   - `RouteConfig.RegisterRoutes()` — registers default `{controller}/{action}/{id}` route
   - `BundleConfig.RegisterBundles()` — registers jQuery, Bootstrap, Modernizr script/style bundles
   - `InitializeDatabase()` — builds `SchoolContext` from `Web.config` connection string and calls `DbInitializer.Initialize(context)`:
     - Calls `context.Database.EnsureCreated()` — creates schema if database does not exist
     - Seeds initial data if `Students` table is empty
3. **First HTTP request** triggers `SchoolContextFactory.Create()` per-request context instantiation

There are no health-check probes, readiness gates, or external service dependencies in the startup chain. The only external dependency — SQL Server LocalDB — is accessed inline during startup via `EnsureCreated()`.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage |
|---|---|---|
| `DefaultConnection` connection string | SQL Server connection string | Plaintext in `Web.config` — Integrated Security (no password) |
| `NotificationQueuePath` | MSMQ queue path | Plaintext in `Web.config` appSettings |

### Secrets Provisioning Workflow

No secrets management system is in place. The sole database connection uses Windows Integrated Security (no username/password), so no credential secret is required for the default configuration. The MSMQ queue path is a local path and contains no sensitive value. There are no API keys, OAuth client secrets, Azure Key Vault references, or encrypted property values anywhere in the configuration.

For production deployments, the `DefaultConnection` string would need to be replaced with a production SQL Server connection string containing credentials. The recommended approach for migration would be to use Azure App Configuration or Azure Key Vault with a managed identity, or use IIS environment variable substitution at deployment time. Currently, no such mechanism exists.

## Feature Flags

| Flag Name | Default | Controlled By |
|---|---|---|
| None configured | — | — |

No feature flag framework (LaunchDarkly, .NET `Microsoft.FeatureManagement`, custom toggles, `@ConditionalOnProperty`) is in use. The commented-out `AuthorizeAttribute` in `FilterConfig.cs` hints at an incomplete authentication feature that was started but not implemented.

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework | 4.8 | `Web.config` `<compilation targetFramework="4.8">`, `<httpRuntime targetFramework="4.8">` |
| ASP.NET MVC | 5.2.9 | `packages.config` |
| ASP.NET Razor | 3.2.9 | `packages.config` |
| ASP.NET WebPages | 3.2.9 | `packages.config` |
| ASP.NET Web Optimization | 1.1.3 | `packages.config` |
| Entity Framework Core | 3.1.32 | `packages.config` |
| EF Core SqlServer | 3.1.32 | `packages.config` |
| Microsoft.Data.SqlClient | 2.1.4 | `packages.config` |
| Microsoft.Identity.Client (MSAL) | 4.21.1 | `packages.config` |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| Bootstrap | 5.3.3 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |
| Application Version | 1.0.0.0 | `Properties/AssemblyInfo.cs` |
| Build Tool | MSBuild (classic .csproj) | `ContosoUniversity.csproj` |
