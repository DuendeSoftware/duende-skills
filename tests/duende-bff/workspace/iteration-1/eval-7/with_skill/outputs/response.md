# Random Logouts in Multi-Instance BFF Deployment

## Root Cause

The default ASP.NET Core Data Protection key ring is stored **in memory** on each instance. When a user authenticates through instance A, the session cookie is encrypted with instance A's key. When the next request hits instance B (via load balancer), instance B can't decrypt the cookie because it has a different key — so the user appears unauthenticated.

## Fix: Shared Data Protection Key Store

```csharp
var builder = WebApplication.CreateBuilder(args);

// 1. Share Data Protection keys across all instances
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>()  // Or PersistKeysToAzureBlobStorage, Redis, etc.
    .SetApplicationName("my-bff-app");

// 2. Use server-side sessions with a shared store
builder.Services.AddBff(options =>
{
    options.SessionCleanupInterval = TimeSpan.FromMinutes(10);
})
.ConfigureOpenIdConnect(options =>
{
    options.Authority = "https://idp.example.com";
    options.ClientId = "spa-bff-client";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;
})
.AddEntityFrameworkServerSideSessions(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
})
.AddSessionCleanupBackgroundProcess();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

## Why Both Are Needed

1. **Data Protection key ring** — The cookie encryption keys must be shared so any instance can decrypt the cookie. Without this, cookies from one instance are garbage to another.
2. **Server-side sessions** — With in-memory sessions (`AddServerSideSessions()`), session data lives only in the process that created it. `AddEntityFrameworkServerSideSessions()` stores session data in a shared database so any instance can look up the session by its ID from the cookie.
