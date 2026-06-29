# Modernization Plan: buildmelbourne-modernization-plan

**Project**: ContosoUniversity

---

## Technical Framework

- **Language**: C# / .NET Framework 4.8
- **Framework**: ASP.NET MVC 5.2.9 (legacy web application, non-SDK-style project)
- **Build Tool**: MSBuild (packages.config NuGet)
- **Database**: SQL Server LocalDB with Entity Framework Core 3.1.32
- **Key Dependencies**: System.Messaging (MSMQ), Microsoft.AspNet.Mvc 5.2.9, Microsoft.EntityFrameworkCore.SqlServer 3.1.32, Newtonsoft.Json 13.0.3, Microsoft.Identity.Client 4.21.1

---

## Overview

> This migration modernizes the ContosoUniversity ASP.NET MVC 5 application from .NET Framework 4.8 to .NET 10, replacing Windows-only dependencies with cloud-native Azure services, and deploying the containerized application to Azure Container Apps with fully provisioned infrastructure.
>
> The application currently runs as a .NET Framework 4.8 ASP.NET MVC 5 web application using MSMQ for notifications, local filesystem for teaching material uploads, and a local SQL Server (LocalDB) database with connection-string authentication. These components are incompatible with containerized cloud deployment.
>
> The new architecture will:
>
> - Upgrade to .NET 10 (ASP.NET Core) for cross-platform container compatibility and long-term support
> - Replace Windows MSMQ (System.Messaging) with Azure Service Bus for cloud-native messaging
> - Replace local filesystem uploads with Azure Blob Storage for persistent, scalable file storage
> - Replace SQL Server LocalDB with Azure SQL Database using Managed Identity (passwordless) authentication
> - Configure console logging for container-compatible log aggregation in Azure Container Apps
> - Provision all required Azure infrastructure via Bicep IaC
> - Deploy as a containerized application to Azure Container Apps
>
> The migration follows a phased approach: runtime upgrade first, then Azure service migrations, security remediation, infrastructure provisioning, and finally containerized deployment.

---

## Migration Impact Summary

| Application         | Original Service                       | New Azure Service          | Authentication   | Comments                                                    |
|---------------------|----------------------------------------|----------------------------|------------------|-------------------------------------------------------------|
| ContosoUniversity   | .NET Framework 4.8 / ASP.NET MVC 5     | .NET 10 / ASP.NET Core     | N/A              | SDK-style project conversion, Web.config to appsettings.json |
| ContosoUniversity   | MSMQ (System.Messaging)               | Azure Service Bus          | Managed Identity | Windows-only queue replaced for container compatibility     |
| ContosoUniversity   | Local Filesystem (~/Uploads/)          | Azure Blob Storage         | Managed Identity | Ephemeral container storage replaced with cloud storage     |
| ContosoUniversity   | SQL Server LocalDB (connection string) | Azure SQL Database         | Managed Identity | Passwordless cloud-native database authentication           |
| ContosoUniversity   | System.Diagnostics.Debug.WriteLine     | Console Logging            | N/A              | Container-ready stdout/stderr log aggregation               |

---

## Proposed Infrastructure Architecture

```
Azure Container Apps Environment
  L__ Container App: ContosoUniversity (ASP.NET Core .NET 10)
        |-- Azure SQL Database (school data)
        |-- Azure Service Bus Namespace / Queue (notifications)
        |-- Azure Storage Account / Blob Container (teaching materials)
        L__ Managed Identity -> role assignments to all Azure services

Azure Container Registry (Docker image hosting)
```

---

## Azure Resource List

| Resource Type               | Resource Name                   | SKU / Tier      | Purpose                                 |
|-----------------------------|---------------------------------|-----------------|-----------------------------------------|
| Azure Container Registry    | acrcontosouniversity            | Basic           | Store and serve Docker container images |
| Azure Container Apps Env    | cae-contosouniversity           | Consumption     | Hosting environment for container apps  |
| Azure Container App         | ca-contosouniversity            | Consumption     | Run the ASP.NET Core web application    |
| Azure SQL Database          | sqldb-contosouniversity         | General Purpose | Persistent school database              |
| Azure Service Bus Namespace | sb-contosouniversity            | Standard        | Cloud-native notification messaging     |
| Azure Service Bus Queue     | ContosoUniversityNotifications  | Standard        | Notification queue (replaces MSMQ)      |
| Azure Storage Account       | stcontosouniversity             | Standard LRS    | Teaching material image blob storage    |
| Blob Container              | teaching-materials              | Hot             | Store course teaching material images   |
| User-Assigned Managed Id    | id-contosouniversity            | N/A             | Passwordless auth to all Azure services |

> **Note**: Estimated costs are based on Azure retail prices and serve as rough estimates only.

---

## Open Questions & Questionnaire

- [x] Q: Should the plan include environment/infrastructure provisioning? -> A: Yes - provision new infrastructure (user explicitly requested)
- [x] Q: Should the plan include integration testing? -> A: No - user did not request integration testing; skip
- [x] Q: Should the plan include security/CVE remediation? -> A: Yes - include (default)
- [x] Q: Which Azure deployment target? -> A: Azure Container Apps (user explicitly requested)
- [x] Q: Should the plan include containerization? -> A: Covered by deployment task (Azure Container Apps deployment includes containerization)
- [x] Q: IaC tool? -> A: Bicep (default for Azure Container Apps)
