# Contoso University - .NET 10

This project is an ASP.NET Core MVC application targeting .NET 10.

## Project Overview

### Framework
- ASP.NET Core MVC (.NET 10)

### Database Access: Entity Framework
- Entity Framework Core 10

### Project Structure
```
ContosoUniversity/
├── Controllers/            # MVC Controllers
├── Data/                   # Entity Framework context and initializer
├── Models/                 # Data models and view models
├── Views/                  # Razor views
├── Content/                # CSS and other content
├── Scripts/                # JavaScript files
├── Properties/             # Assembly properties
├── Program.cs              # Application startup and middleware pipeline
└── appsettings.json        # Configuration file
```

## Database Configuration

The application uses SQL Server LocalDB with the following connection string in `appsettings.json`:
```json
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=(LocalDb)\\MSSQLLocalDB;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True"
  }
```

## Running the Application

1. **Prerequisites**:
   - Visual Studio 2022 or later (or .NET 10 SDK)
   - SQL Server LocalDB

2. **Setup**:
   - Open the project in Visual Studio
   - Restore NuGet packages
   - Build the solution
   - Run using `dotnet run`

## Features

- **Student Management**: CRUD operations for students with pagination and search
- **Course Management**: Manage courses and their assignments to departments
- **Instructor Management**: Handle instructor assignments and office locations
- **Department Management**: Manage departments and their administrators
- **Statistics**: View enrollment statistics by date

## Database Initialization

The application uses Entity Framework Core Code First with a database initializer that:
- Creates the database if it doesn't exist
- Seeds sample data including students, instructors, courses, and departments
- Handles model changes by recreating the database
