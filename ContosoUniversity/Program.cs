using ContosoUniversity.Data;
using ContosoUniversity.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllersWithViews();
builder.Services.AddDbContext<SchoolContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddSingleton<NotificationService>();

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

// Also serve static files from Content/, Scripts/, and Uploads/ in project root
var contentRootPath = builder.Environment.ContentRootPath;

if (Directory.Exists(Path.Combine(contentRootPath, "Content")))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(Path.Combine(contentRootPath, "Content")),
        RequestPath = "/Content"
    });
}

if (Directory.Exists(Path.Combine(contentRootPath, "Scripts")))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(Path.Combine(contentRootPath, "Scripts")),
        RequestPath = "/Scripts"
    });
}

if (Directory.Exists(Path.Combine(contentRootPath, "Uploads")))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(Path.Combine(contentRootPath, "Uploads")),
        RequestPath = "/Uploads"
    });
}

app.UseRouting();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
