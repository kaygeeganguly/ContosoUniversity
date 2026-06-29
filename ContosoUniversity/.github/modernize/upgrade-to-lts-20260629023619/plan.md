# .NET Upgrade Plan: ContosoUniversity

## Overview

Upgrade **ContosoUniversity** from **.NET Framework 4.8** to **.NET 10.0** (latest LTS).

The project is an ASP.NET MVC 5 web application using the legacy non-SDK-style project format. Migrating to .NET 10.0 requires converting to the SDK-style project format and replacing .NET Framework-specific APIs and packages with their modern .NET equivalents.

## Source & Target Versions

| | Version |
|---|---|
| **Source** | .NET Framework 4.8 |
| **Target** | .NET 10.0 (`net10.0`) |

## Projects in Solution

| Project | Path | Type |
|---|---|---|
| ContosoUniversity | `ContosoUniversity/ContosoUniversity.csproj` | ASP.NET MVC 5 Web Application (.NET Framework 4.8) |

## Upgrade Scope

1. **SDK-style project conversion** — Convert `ContosoUniversity.csproj` from the legacy `<Project xmlns="...">` format to the modern SDK-style `<Project Sdk="Microsoft.NET.Sdk.Web">` format. Remove `packages.config` and migrate NuGet references to `<PackageReference>` items in the project file.

2. **Target framework update** — Replace `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` with `<TargetFramework>net10.0</TargetFramework>`.

3. **ASP.NET MVC → ASP.NET Core migration** — `System.Web`-based MVC 5 is not supported on .NET 10. Controllers, routing, bundling, filters, and views must be migrated to ASP.NET Core MVC equivalents. `Global.asax` must be replaced with `Program.cs` / startup configuration.

4. **NuGet package updates** — Replace legacy packages (e.g., `Microsoft.AspNet.Mvc`, `Microsoft.AspNet.WebPages`, `WebGrease`, `Antlr`) with their .NET 10-compatible equivalents. Update `Microsoft.EntityFrameworkCore` from 3.1.x to the latest stable release compatible with .NET 10.

5. **API compatibility fixes** — Identify and fix any APIs removed or changed between .NET Framework 4.8 and .NET 10 (e.g., `System.Web`, `HttpContext`, `HttpResponse`, bundling/minification, authentication/authorization, configuration via `Web.config`).

6. **Configuration migration** — Replace `Web.config`-based configuration with `appsettings.json` and the `Microsoft.Extensions.Configuration` model used by ASP.NET Core.

## Reason for Upgrade

The user explicitly requested an upgrade to the latest LTS version. Additionally, .NET Framework 4.8 is a legacy platform with no new feature development; migrating to .NET 10.0 LTS provides long-term support, improved performance, cross-platform capability, and access to modern ASP.NET Core features.
