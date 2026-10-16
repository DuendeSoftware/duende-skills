# Fix for random logouts across 3 instances

Two per-instance defaults cause this:

**1. Server-side session store.** In-memory sessions aren't shared: a request landing on another node doesn't find the session. Use a persistent shared store:

```csharp
builder.Services.AddBff(o => o.SessionCleanupInterval = TimeSpan.FromMinutes(10))
    .ConfigureOpenIdConnect(o => { /* ... */ })
    .AddEntityFrameworkServerSideSessions(o => o.UseSqlServer(connectionString))
    .AddSessionCleanupBackgroundProcess();
```
(`dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext`; `dotnet ef database update`.)

**2. Data Protection keys.** Cookies and anti-forgery tokens must be decryptable by every node:

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("MyBff")
    .PersistKeysToDbContext<ApplicationDbContext>();
// or Azure Blob + ProtectKeysWithAzureKeyVault
```
The default in-memory key ring makes each node generate its own keys, so users appear perpetually logged out. Also ensure forwarded headers are configured behind the load balancer. Do both; sticky sessions are not the recommended fix.
