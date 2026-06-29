using Azure.Identity;
using Azure.Storage.Blobs;
using ContosoUniversity.Data;
using ContosoUniversity.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllersWithViews();
builder.Services.AddDbContext<SchoolContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddSingleton<NotificationService>();

// Register Azure Blob Storage BlobServiceClient as Singleton.
// BlobServiceClient is thread-safe and designed to be reused — always registered as Singleton.
// Uses DefaultAzureCredential (Managed Identity) for authentication — no connection strings or keys.
builder.Services.AddSingleton(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var serviceUri = new Uri(config["Storage:ServiceUri"]
        ?? throw new InvalidOperationException("Storage:ServiceUri is not configured."));
    return new BlobServiceClient(serviceUri, new DefaultAzureCredential());
});

// Register BlobStorageService as Singleton (holds a BlobContainerClient derived from BlobServiceClient)
builder.Services.AddSingleton<IBlobStorageService, BlobStorageService>();

var app = builder.Build();

// Initialize database
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

// Serve static files from the default wwwroot folder
app.UseStaticFiles();

// Also serve static files from Content/ and Scripts/ in project root
var contentRootPath = builder.Environment.ContentRootPath;

if (Directory.Exists(Path.Combine(contentRootPath, "Content")))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(Path.Combine(contentRootPath, "Content")),
        RequestPath = "/Content"
    });
}

if (Directory.Exists(Path.Combine(contentRootPath, "Scripts")))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(Path.Combine(contentRootPath, "Scripts")),
        RequestPath = "/Scripts"
    });
}

// NOTE: The Uploads/TeachingMaterials/ static file middleware has been removed.
// Teaching material images are now stored in Azure Blob Storage and served via their blob URLs.

app.UseRouting();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
