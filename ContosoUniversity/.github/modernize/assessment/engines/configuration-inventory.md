# Configuration & Externalized Settings Inventory

ContosoUniversity is configured through two XML-based `Web.config` files (root and Views) with no environment-specific overrides, no external config server, and no secrets store — all settings including the database connection string are stored in plaintext in the root `Web.config`.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|--------|------|--------------|-------|
| Root Web.config | XML (ASP.NET config) | `ContosoUniversity/Web.config` | Primary configuration: connection strings, app settings, HTTP runtime, assembly binding redirects |
| Views Web.config | XML (Razor/MVC config) | `ContosoUniversity/Views/Web.config` | Razor host factory and view page base type; webpages flags |
| packages.config | XML (NuGet manifest) | `ContosoUniversity/packages.config` | NuGet package versions — build-time only, not a runtime config source |
| AssemblyInfo.cs | C# attribute | `ContosoUniversity/Properties/AssemblyInfo.cs` | Assembly version, GUID, copyright metadata |

**No external configuration sources detected**: There is no `appsettings.json`, `launchSettings.json`, Spring Cloud Config, Azure App Configuration, Consul KV, or `.env` file. There is no `Web.Debug.config` or `Web.Release.config` with active transforms (both files exist but contain only commented-out template transform examples).

## Build Profiles

| Profile | Activation | Purpose | Key Behaviors |
|---------|-----------|---------|---------------|
| Debug | Default in VS; `Configuration=Debug` MSBuild property | Development build with debug symbols | `debug="true"` in compilation; `DebugType=full`; `DefineConstants=DEBUG;TRACE`; no optimization |
| Release | Manual or CI; `Configuration=Release` MSBuild property | Production build | `DebugType=pdbonly`; `Optimize=true`; `DefineConstants=TRACE` |

No Maven profiles, Gradle build variants, or custom MSBuild targets are defined for environment-specific builds. The `Web.Debug.config` and `Web.Release.config` transform files exist but contain only the default Visual Studio placeholder comments — no active XDT transforms are configured.

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---------|-----------------|-------------|--------------|
| (Single profile) | N/A — no runtime profiles | `Web.config` | All environments share the same configuration |

**No runtime profiles configured.** The application does not use `ASPNETCORE_ENVIRONMENT`, `web.config` environment transforms with active rules, or `appsettings.{Environment}.json` files. There is no separation between development, staging, and production configuration — the LocalDB connection string used for development would need to be manually replaced for any other deployment.

## Properties Inventory

### Connection Strings (Web.config → `<connectionStrings>`)

| Property Key | Value / Default | Source |
|-------------|----------------|--------|
| DefaultConnection | `Data Source=(LocalDb)\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True` | Web.config |

### App Settings (Web.config → `<appSettings>`)

| Property Key | Value | Source |
|-------------|-------|--------|
| webpages:Version | `3.0.0.0` | Web.config |
| webpages:Enabled | `false` | Web.config |
| ClientValidationEnabled | `true` | Web.config |
| UnobtrusiveJavaScriptEnabled | `true` | Web.config |
| NotificationQueuePath | `.\Private$\ContosoUniversityNotifications` | Web.config |

### Views App Settings (Views/Web.config → `<appSettings>`)

| Property Key | Value | Source |
|-------------|-------|--------|
| webpages:Version | `3.0.0.0` | Views/Web.config (overrides root scope for Views) |
| webpages:Enabled | `false` | Views/Web.config |

### HTTP Runtime Settings (Web.config → `<system.web>`)

| Property Key | Value | Source |
|-------------|-------|--------|
| compilation debug | `true` | Web.config |
| compilation targetFramework | `4.8` | Web.config |
| httpRuntime targetFramework | `4.8` | Web.config |
| httpRuntime maxRequestLength | `10240` (10 MB) | Web.config |
| httpRuntime executionTimeout | `3600` seconds (1 hour) | Web.config |

### IIS / Web Server Settings (Web.config → `<system.webServer>`)

| Property Key | Value | Source |
|-------------|-------|--------|
| requestLimits maxAllowedContentLength | `10485760` bytes (10 MB) | Web.config |
| validateIntegratedModeConfiguration | `false` | Web.config |

## Startup Parameters & Resource Requirements

| Parameter | Value | Notes |
|-----------|-------|-------|
| Target framework | .NET Framework 4.8 | Declared in `ContosoUniversity.csproj` as `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` |
| Web server host | IIS Express (development); IIS (production) | Configured via `<UseIISExpress>true</UseIISExpress>` in project file |
| Development HTTPS port | 44300 | IIS Express SSL port in project file |
| Development HTTP port | 58801 | IIS Express development server port in project file |
| JVM / heap settings | N/A | .NET Framework CLR — no JVM; no explicit CLR memory limits set |
| Instance count | 1 (single process) | No horizontal scaling configuration |
| Container/Docker config | None | No Dockerfile or docker-compose.yml present |
| Kubernetes config | None | No K8s manifests present |

## Startup Dependency Chain

The application has a simple single-process startup sequence with no inter-service dependencies:

1. **IIS / IIS Express** starts the application process, loads `Global.asax.cs`
2. **`Application_Start()`** runs synchronously:
   - Registers MVC areas
   - Registers global filters (`FilterConfig`)
   - Registers routes (`RouteConfig`)
   - Registers script/style bundles (`BundleConfig`)
   - Calls `InitializeDatabase()`:
     - Reads `DefaultConnection` from `Web.config`
     - Creates `SchoolContext` with `UseSqlServer(connectionString)`
     - Calls `DbInitializer.Initialize(context)` → `context.Database.EnsureCreated()` + seed data
3. **SQL Server LocalDB** must be available when `EnsureCreated()` is called. If it is unavailable, the application throws an unhandled exception at startup and the site fails to start.

**No Docker Compose `depends_on`, no Kubernetes readiness probes, and no retry/wait mechanisms** are configured. There is no health endpoint to indicate readiness.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage | Masked Value |
|-----------------|------|---------|-------------|
| DefaultConnection connection string | SQL Server connection string | Plaintext in `Web.config` | `...Integrated Security=True...` (Windows auth — no password) |
| NotificationQueuePath | MSMQ queue path | Plaintext in `Web.config` | `.\Private$\ContosoUniversityNotifications` |

**Security posture**: The current database connection uses Windows Integrated Security — there is no SQL username/password stored in the config. However, the connection string is committed in plaintext to source control. No Azure Key Vault, HashiCorp Vault, DPAPI, or `secrets.xml` secret manager is used. If a SQL username/password were ever added, it would be exposed in the repository.

### Secrets Provisioning Workflow

No secrets provisioning workflow exists. All configuration is static and stored directly in `Web.config`. There is no:
- Environment variable injection mechanism
- GitHub Actions secrets binding
- Managed identity or service principal for config access
- Secret rotation process

For production deployments, the `DefaultConnection` string would need to be manually replaced via Web.config transforms, environment-specific deployment scripts, or IIS application setting overrides — none of which are currently configured.

## Feature Flags

No feature flag framework is configured. The application does not use:
- `[ConditionalOnProperty]` or `@ConditionalOnExpression` (Spring)
- `Microsoft.FeatureManagement`
- LaunchDarkly, Unleash, or any other feature flag service
- Custom toggle configuration keys

| Flag Name | Default | Controlled By |
|-----------|---------|--------------|
| ClientValidationEnabled | `true` | `Web.config` appSettings |
| UnobtrusiveJavaScriptEnabled | `true` | `Web.config` appSettings |

The above two are framework control flags, not feature flags in the modern sense.

## Framework & Runtime Versions

| Component | Version | Source |
|-----------|---------|--------|
| .NET Framework | 4.8 | `Web.config` `<compilation targetFramework="4.8">` / `.csproj` |
| ASP.NET MVC | 5.2.9 | `packages.config` + assembly binding redirect |
| ASP.NET Razor | 3.2.9 | `packages.config` |
| ASP.NET WebPages | 3.2.9 | `packages.config` |
| ASP.NET Web Optimization | 1.1.3 | `packages.config` |
| Entity Framework Core | 3.1.32 | `packages.config` |
| Microsoft.Data.SqlClient | 2.1.4 | `packages.config` |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| Microsoft.Identity.Client (MSAL) | 4.21.1 | `packages.config` |
| Bootstrap | 5.3.3 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |
| jQuery Validation | 1.21.0 | `packages.config` |
| Microsoft.CodeDom.Providers.DotNetCompilerPlatform | 2.0.1 | `packages.config` |
| Assembly version | 1.0.0.0 | `Properties/AssemblyInfo.cs` |
| Build tool | MSBuild (Visual Studio 15.0 ToolsVersion) | `ContosoUniversity.csproj` |
| IIS Express | n/a (Visual Studio default) | `.csproj` `<UseIISExpress>true</UseIISExpress>` |
