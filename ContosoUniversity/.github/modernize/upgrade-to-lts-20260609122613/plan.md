# Upgrade Plan: ContosoUniversity — .NET Framework 4.8 → .NET 10

## Overview

This plan upgrades the **ContosoUniversity** application from **.NET Framework 4.8** to **.NET 10.0 (LTS)**, the current latest Long-Term Support release.

The project is a classic ASP.NET MVC 5 web application using the legacy non-SDK-style project format. Migrating to .NET 10.0 requires a full SDK-style project conversion and migration from `System.Web`-based ASP.NET MVC to **ASP.NET Core MVC**.

## Source Version

- **Framework**: .NET Framework 4.8
- **Project format**: Legacy (non-SDK-style `.csproj`)
- **Web framework**: ASP.NET MVC 5 (`System.Web.Mvc 5.2.9`)
- **ORM**: Entity Framework Core 3.1.32

## Target Version

- **Framework**: .NET 10.0 (`net10.0`) — latest LTS
- **Project format**: SDK-style `.csproj`
- **Web framework**: ASP.NET Core MVC
- **ORM**: Entity Framework Core (latest compatible with .NET 10)

## Projects in Solution

| Project | Path | Current TFM |
|---------|------|-------------|
| ContosoUniversity | `ContosoUniversity/ContosoUniversity.csproj` | net48 (.NET Framework 4.8) |

## Upgrade Scope

1. **SDK-style project conversion** — Replace legacy `.csproj` with SDK-style format; remove `packages.config` in favour of PackageReference.
2. **Target framework update** — Change `TargetFrameworkVersion v4.8` → `<TargetFramework>net10.0</TargetFramework>`.
3. **ASP.NET MVC → ASP.NET Core MVC migration** — Replace `System.Web`, `Global.asax`, `Web.config`, `App_Start`, `RouteConfig`, `BundleConfig`, `FilterConfig` with ASP.NET Core equivalents (`Program.cs`, `Startup`-style configuration, middleware pipeline).
4. **NuGet package updates** — Upgrade `Microsoft.EntityFrameworkCore.*`, `Microsoft.Extensions.*`, and all other packages to versions compatible with .NET 10.
5. **API compatibility fixes** — Address any breaking changes surfaced by the upgrade (e.g., `System.Web` removals, `HttpContext` differences, `System.Messaging` removal).
6. **Configuration migration** — Move `Web.config` connection strings and app settings to `appsettings.json`.

## Reason for Upgrade

The user explicitly requested an upgrade to the latest LTS version. Additionally, .NET Framework 4.8 is a legacy platform with no new feature development; .NET 10 LTS provides long-term support through May 2028, improved performance, modern APIs, and cross-platform compatibility.
