# Configuration & Externalized Settings Inventory

ContosoUniversity uses a single XML-based configuration source (`Web.config`) with no environment profiles, no secrets store integration, and no externalized configuration service — all settings are baked directly into the committed configuration file.

## Configuration Sources

| Source | Type | Path / Location | Notes |
|---|---|---|---|
| `Web.config` | XML (ASP.NET configuration) | `ContosoUniversity/Web.config` | Primary config: connection strings, app settings, HTTP runtime, assembly binding redirects |
| `Views/Web.config` | XML (Razor view configuration) | `ContosoUniversity/Views/Web.config` | Razor host/pages configuration; prevents direct HTTP access to view files |
| `packages.config` | XML (NuGet package manifest) | `ContosoUniversity/packages.config` | Declares NuGet package versions for .NET Framework package restore |
| `App_Start/BundleConfig.cs` | C# (code-based config) | `ContosoUniversity/App_Start/BundleConfig.cs` | CSS/JS bundle definitions for Web.Optimization |
| `App_Start/RouteConfig.cs` | C# (code-based config) | `ContosoUniversity/App_Start/RouteConfig.cs` | URL routing table (single default `{controller}/{action}/{id}` route) |
| `App_Start/FilterConfig.cs` | C# (code-based config) | `ContosoUniversity/App_Start/FilterConfig.cs` | Global MVC filter registration (`HandleErrorAttribute`) |

No `appsettings.json`, `launchSettings.json`, `.env` files, Spring Cloud Config, Azure App Configuration, AWS AppConfig, HashiCorp Vault, Azure Key Vault, or Kubernetes ConfigMaps/Secrets are present.

## Build Profiles

| Profile | Activation | Purpose | Key Changes |
|---|---|---|---|
| Debug | Default (Visual Studio / MSBuild) | Local development; enables debug symbols | `<compilation debug="true">` in `Web.config`; debug PDB output |
| Release | Manual (`/p:Configuration=Release`) | Production packaging; disables debug, enables optimisation | Removes debug symbols; Web.Optimization bundling/minification enabled |

No Maven/Gradle build profiles and no conditional compilation symbols beyond the standard Debug/Release pair are defined.

## Runtime Profiles

| Profile | Activation | Config Files | Key Overrides |
|---|---|---|---|
| (Single profile — no environment separation) | N/A | `Web.config` only | No per-environment overrides; all environments use identical settings |

The application has no `appsettings.Development.json` / `appsettings.Production.json` equivalent, no `ASPNETCORE_ENVIRONMENT` variable, and no Spring-style profile system. Configuration is entirely static and environment-agnostic.

## Properties Inventory

### Connection Strings (`Web.config` → `<connectionStrings>`)

| Property Key | Default Value | Profile | Source |
|---|---|---|---|
| `DefaultConnection` | `Data Source=(LocalDb)\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | All | `Web.config` |

### Application Settings (`Web.config` → `<appSettings>`)

| Property Key | Default Value | Profile | Source |
|---|---|---|---|
| `webpages:Version` | `3.0.0.0` | All | `Web.config` |
| `webpages:Enabled` | `false` | All | `Web.config` |
| `ClientValidationEnabled` | `true` | All | `Web.config` |
| `UnobtrusiveJavaScriptEnabled` | `true` | All | `Web.config` |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | All | `Web.config` |

### HTTP Runtime (`Web.config` → `<system.web>`)

| Property | Value | Notes |
|---|---|---|
| `compilation debug` | `true` | Should be `false` in production |
| `httpRuntime targetFramework` | `4.8` | .NET Framework 4.8 target |
| `httpRuntime maxRequestLength` | `10240` (KB = 10 MB) | Maximum HTTP request body size |
| `httpRuntime executionTimeout` | `3600` seconds (1 hour) | Request execution timeout — unusually long |

### Web Server (`Web.config` → `<system.webServer>`)

| Property | Value | Notes |
|---|---|---|
| `requestLimits maxAllowedContentLength` | `10485760` bytes (10 MB) | IIS request size limit |
| `validateIntegratedModeConfiguration` | `false` | Suppresses IIS mode validation errors |

## Startup Parameters & Resource Requirements

| Service | Runtime Options | Memory Limits | Instance Count |
|---|---|---|---|
| ContosoUniversity Web App | .NET Framework 4.8 CLR; no JVM; no `-Xms`/`-Xmx`; execution timeout 3600 s; request limit 10 MB | Not specified (IIS application pool default) | 1 (no scaling config defined) |

No Docker, Kubernetes, or cloud deployment manifests are present. Resource limits depend entirely on the IIS application pool and host OS configuration.

## Startup Dependency Chain

1. **IIS / IIS Express** starts and loads the application pool (Classic or Integrated Pipeline mode)
2. **`Global.asax.cs` `Application_Start`** fires:
   - `AreaRegistration.RegisterAllAreas()`
   - `FilterConfig.RegisterGlobalFilters()`
   - `RouteConfig.RegisterRoutes()`
   - `BundleConfig.RegisterBundles()`
   - `InitializeDatabase()` → `SchoolContextFactory.Create()` → `DbInitializer.Initialize(context)` → `context.Database.EnsureCreated()` + seed data
3. **MSMQ queue** (`.\Private$\ContosoUniversityNotifications`) — `NotificationService` constructor creates or opens the queue on first controller instantiation (lazy, not at startup)

There are no readiness probes, health-check endpoints, `dockerize` wait-for-TCP mechanisms, or Kubernetes liveness/readiness probes. If SQL Server LocalDB is unavailable at startup, `EnsureCreated()` will throw and the application will fail to start.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Location | Masked Value |
|---|---|---|---|
| `DefaultConnection` connection string | Database connection string | `Web.config` → `<connectionStrings>` | Uses **Integrated Security** (Windows auth — no password in config) |

No database passwords, API keys, or bearer tokens are stored in configuration files. The SQL Server connection uses Windows Integrated Security, which avoids credentials in `Web.config` but ties the application to Windows domain authentication.

### Secrets Provisioning Workflow

**No secrets management workflow is in place.** The single sensitive configuration item — the database connection string — uses Windows Integrated Security, so no password appears in `Web.config`. However:

- The connection string itself (server name, database name) is committed in plaintext.
- There is no Azure Key Vault, HashiCorp Vault, AWS Secrets Manager, or `.env` injection.
- There are no GitHub Actions secrets, environment variable overrides, or DPAPI-encrypted config sections.
- When migrating to Azure, the connection string will need to be moved to Azure App Configuration or Key Vault and injected at runtime via managed identity or environment variables.

## Feature Flags

No feature flag framework is configured. There are no `[ConditionalOnProperty]` annotations, LaunchDarkly integrations, .NET `IFeatureManager` registrations, or custom toggle implementations. The only conditionally disabled feature is the global `AuthorizeAttribute`, which is commented out in `FilterConfig.cs`.

| "Flag" | State | Controlled By | Notes |
|---|---|---|---|
| Global authentication requirement | Disabled (commented out) | `App_Start/FilterConfig.cs` source code | `// filters.Add(new AuthorizeAttribute())` — requires code change to enable |

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework | 4.8 | `Web.config` `targetFramework="4.8"`, `packages.config` `targetFramework="net482"` |
| ASP.NET MVC | 5.2.9 | `packages.config`, `Views/Web.config` |
| ASP.NET Razor | 3.2.9 | `packages.config` |
| ASP.NET WebPages | 3.2.9 | `packages.config` |
| Entity Framework Core | 3.1.32 | `packages.config` |
| Microsoft.Data.SqlClient | 2.1.4 | `packages.config` |
| Microsoft.Identity.Client (MSAL) | 4.21.1 | `packages.config` |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |
| Bootstrap | 5.3.3 | `packages.config` |
| System.Messaging (MSMQ) | .NET 4.8 built-in | N/A — part of .NET Framework BCL |
| MSBuild | Bundled with Visual Studio / .NET SDK | `ContosoUniversity.csproj` |
| Assembly version | 1.0.0.0 | `Properties/AssemblyInfo.cs` |
