# Configuration & Externalized Settings Inventory

This inventory captures the configuration files and externalized settings used by ContosoUniversity, including runtime defaults and sensitive value handling patterns.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| `Web.config` | XML runtime config | `ContosoUniversity/Web.config` | Connection string, app settings, request limits, binding redirects |
| `Web.Debug.config` | Build transform | `ContosoUniversity/Web.Debug.config` | Debug transform overlay |
| `Web.Release.config` | Build transform | `ContosoUniversity/Web.Release.config` | Release transform overlay |
| `packages.config` | Dependency config | `ContosoUniversity/packages.config` | Declares NuGet packages and versions |
| `.csproj` property groups | Build/runtime metadata | `ContosoUniversity/ContosoUniversity.csproj` | Target framework, output paths, IIS Express settings |

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| Debug | `Configuration=Debug` | Local development build with symbols | Standard .NET Framework build targets |
| Release | `Configuration=Release` | Optimized production-like build | Standard .NET Framework build targets |

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| Default IIS-hosted profile | IIS/IIS Express startup | `Web.config` | `DefaultConnection`, upload size/time limits, notification queue path |

## Properties Inventory

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `DefaultConnection` | LocalDB connection string | default | `Web.config` connectionStrings |
| `NotificationQueuePath` | `.\Private$\ContosoUniversityNotifications` | default | `Web.config` appSettings |
| `ClientValidationEnabled` | `true` | default | `Web.config` appSettings |
| `UnobtrusiveJavaScriptEnabled` | `true` | default | `Web.config` appSettings |
| `httpRuntime.maxRequestLength` | `10240` | default | `Web.config` |
| `httpRuntime.executionTimeout` | `3600` | default | `Web.config` |
| `requestLimits.maxAllowedContentLength` | `10485760` | default | `Web.config` |

## Startup Parameters & Resource Requirements

| Service | JVM/Runtime Options | Memory | Instance Count |
|---|---|---|---|
| ContosoUniversity Web App | .NET Framework 4.8, IIS-hosted | Not explicitly configured in repo | 1 (implicit single-instance local setup) |

## Startup Dependency Chain

1. IIS/IIS Express starts the ASP.NET MVC application.
2. `Application_Start` registers routes/filters/bundles.
3. Database initialization runs (`UseSqlServer` + `DbInitializer.Initialize`).
4. Controllers create `SchoolContext` instances and begin serving requests.
5. Notification workflows lazily initialize MSMQ queue when `NotificationService` is used.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage (masked) |
|---|---|---|
| `DefaultConnection` | Database connection string | `Web.config` (Integrated Security, credentials not embedded) |
| `NotificationQueuePath` | Infrastructure endpoint | `Web.config` appSettings |

### Secrets Provisioning Workflow

Secrets/configuration are file-based in `Web.config` for this repository snapshot. At application startup, the connection string is read via `ConfigurationManager` and bound to EF Core `UseSqlServer`. Notification queue settings are read from app settings and used to create/connect to the MSMQ queue. No external secret vault integration was detected.

## Feature Flags

| Flag Name | Default | Controlled By |
|---|---|---|
| None detected | N/A | N/A |

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| .NET Framework | 4.8 | `ContosoUniversity.csproj` |
| ASP.NET MVC | 5.2.9 | `packages.config` |
| Entity Framework Core | 3.1.32 | `packages.config` |
| SQL Client | 2.1.4 | `packages.config` |
| Newtonsoft.Json | 13.0.3 | `packages.config` |
| Bootstrap | 5.3.3 | `packages.config` |
| jQuery | 3.7.1 | `packages.config` |

