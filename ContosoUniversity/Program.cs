using System.IO;
using Azure.Identity;
using ContosoUniversity.Data;
using ContosoUniversity.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Azure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Add MVC with views
builder.Services.AddControllersWithViews();

// Add EF Core with SQL Server
builder.Services.AddDbContext<SchoolContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register notification service as scoped (uses Azure Service Bus with Managed Identity)
builder.Services.AddScoped<NotificationService>();

// Register Azure Blob Storage client as Singleton using DefaultAzureCredential (Managed Identity)
// Rule: BlobServiceClient is thread-safe and must be registered as Singleton to avoid per-request
// AAD token acquisition overhead and TCP connection pool exhaustion.
builder.Services.AddAzureClients(clientBuilder =>
{
    clientBuilder.AddBlobServiceClient(builder.Configuration.GetSection("Storage"));
    clientBuilder.UseCredential(new DefaultAzureCredential());
});

// Register BlobStorageService as Singleton (holds BlobContainerClient derived from BlobServiceClient)
builder.Services.AddSingleton<BlobStorageService>();

var app = builder.Build();

// Initialize the database
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<SchoolContext>();
    DbInitializer.Initialize(context);
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();

// Serve files from wwwroot (default)
app.UseStaticFiles();

// Serve legacy Content/ directory (CSS, etc.)
var contentDir = Path.Combine(app.Environment.ContentRootPath, "Content");
if (Directory.Exists(contentDir))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(contentDir),
        RequestPath = "/Content"
    });
}

// Serve legacy Scripts/ directory
var scriptsDir = Path.Combine(app.Environment.ContentRootPath, "Scripts");
if (Directory.Exists(scriptsDir))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(scriptsDir),
        RequestPath = "/Scripts"
    });
}

// NOTE: The local Uploads/ static files middleware has been removed.
// Teaching material images are now stored in and served directly from Azure Blob Storage.

app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();