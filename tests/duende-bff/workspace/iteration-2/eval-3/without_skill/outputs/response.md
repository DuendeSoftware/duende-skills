To set up server-side sessions with EF Core and SQL Server for your BFF, here's the approach:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff();

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "OpenIdConnect";
})
.AddCookie("Cookies")
.AddOpenIdConnect("OpenIdConnect", options =>
{
    options.Authority = "https://idp.example.com";
    options.ClientId = "spa-bff-client";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;
});

// Add server-side sessions with EF Core
builder.Services.AddServerSideSessions(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

You'll also want to set up some kind of periodic cleanup to remove expired sessions. You could use a hosted background service:

```csharp
public class SessionCleanupService : BackgroundService
{
    private readonly IServiceProvider _services;

    public SessionCleanupService(IServiceProvider services) => _services = services;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // Clean up expired sessions every 10 minutes
            await Task.Delay(TimeSpan.FromMinutes(10), stoppingToken);
            // Cleanup logic here
        }
    }
}
```

Register the cleanup service:
```csharp
builder.Services.AddHostedService<SessionCleanupService>();
```
