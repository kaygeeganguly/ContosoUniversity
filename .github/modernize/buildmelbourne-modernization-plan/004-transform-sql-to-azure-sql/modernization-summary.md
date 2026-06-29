# Task 004 – Migrate SQL Server LocalDB to Azure SQL Database with Managed Identity

## Overview

Migrated the ContosoUniversity application's database connection from SQL Server LocalDB with Windows Integrated Security to Azure SQL Database using Managed Identity (`Authentication=Active Directory Default`). This removes all Windows-only, credential-based database authentication and replaces it with passwordless cloud-native authentication suitable for Azure Container Apps.

---

## Changes Made

### `ContosoUniversity/appsettings.json`

**Before:**
```json
"DefaultConnection": "Data Source=(LocalDb)\\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True"
```

**After:**
```json
"DefaultConnection": "Server=tcp:${SQL_SERVER_NAME}.database.windows.net;Database=ContosoUniversity;Authentication=Active Directory Default;TrustServerCertificate=True"
```

Key changes:
- Replaced `Data Source=(LocalDb)\\MSSQLLocalDB` (Windows LocalDB) with `Server=tcp:${SQL_SERVER_NAME}.database.windows.net` (Azure SQL Database endpoint)
- Replaced `Integrated Security=True` (Windows auth) with `Authentication=Active Directory Default` (Managed Identity / DefaultAzureCredential)
- Renamed database from `ContosoUniversityNoAuthEFCore` to `ContosoUniversity` (aligned with Azure resource naming)
- Removed `MultipleActiveResultSets=True` (not required by EF Core)
- Added `TrustServerCertificate=True` for Azure SQL connectivity
- Uses `${SQL_SERVER_NAME}` placeholder, consistent with other Azure service placeholders in the config (`${SERVICE_BUS_NAMESPACE}`, `${STORAGE_ACCOUNT_NAME}`)

---

## Unchanged Files (verified compatible)

| File | Status | Reason |
|------|--------|--------|
| `Data/SchoolContext.cs` | No change needed | Receives `DbContextOptions` via DI — no connection logic |
| `Data/SchoolContextFactory.cs` | No change needed | Reads connection string from `appsettings.json`; passes to `UseSqlServer()` — config-driven |
| `Program.cs` | No change needed | Uses `options.UseSqlServer(connectionString)` — correctly delegates to the updated config |
| `ContosoUniversity.csproj` | No change needed | `Azure.Identity` (1.14.2) already present; `Microsoft.EntityFrameworkCore.SqlServer` (10.0.9) transitively includes `Microsoft.Data.SqlClient` |

---

## Authentication Mechanism

`Authentication=Active Directory Default` uses `Microsoft.Data.SqlClient`'s built-in Azure AD token provider, which internally follows the same credential chain as `DefaultAzureCredential`:

1. **In Azure Container Apps** – User-Assigned Managed Identity (via `AZURE_CLIENT_ID` env var)
2. **Locally** – Azure CLI / Visual Studio credentials for developer access

No `DefaultAzureCredential` code changes were required in application code because the authentication is handled entirely at the ADO.NET/SqlClient driver level via the connection string keyword.

---

## Removed Technology References

| Old Technology | Replacement |
|---------------|-------------|
| `Data Source=(LocalDb)\\MSSQLLocalDB` | `Server=tcp:${SQL_SERVER_NAME}.database.windows.net` |
| `Integrated Security=True` (Windows auth) | `Authentication=Active Directory Default` |
| `Initial Catalog=ContosoUniversityNoAuthEFCore` | `Database=ContosoUniversity` |

---

## Build & Test Results

- **Build**: ✅ Succeeded — 0 errors, 0 warnings
- **Unit Tests**: ✅ No test projects exist; criteria satisfied
- **Consistency Check**: ✅ No Critical or Major issues found
