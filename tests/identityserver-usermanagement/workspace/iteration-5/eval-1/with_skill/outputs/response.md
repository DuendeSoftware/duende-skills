# Adding Duende User Management with Passwordless Email OTP (SQLite)

Here's the complete setup to add Duende User Management to your existing IdentityServer project with passwordless email OTP login backed by SQLite.

## 1. NuGet Packages

Add the User Management and SQLite storage packages (you already reference `Duende.IdentityServer`):

```bash
dotnet add package Duende.UserManagement.IdentityServer8
dotnet add package Duende.Storage.Sqlite
```

Your `IdentityServer.csproj` should end up with:

```xml
<ItemGroup>
  <PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
  <PackageReference Include="Duende.UserManagement.IdentityServer8" Version="8.0.0" />
  <PackageReference Include="Duende.Storage.Sqlite" Version="8.0.0" />
</ItemGroup>
```

> User Management requires the **.NET 10 SDK** — your project already targets `net10.0`, so you're good.

## 2. Program.cs Changes

User Management is configured **on the IdentityServer builder** via `AddUserManagement()`. The important detail: **storage and OTP delivery are configured *inside* the `AddUserManagement()` options lambda**, not at the top level.

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Duende.UserManagement;         // AddUserManagement, IOtpDispatcher, ConsoleOtpDispatcher
using Duende.Storage;                // IDatabaseSchema

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;

    // Point IdentityServer at your account pages
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        // Storage — MUST be configured inside this lambda
        options.AddSqliteStore("Data Source=users.db");

        // Passwordless email OTP delivery.
        // For development you can use the console dispatcher (below);
        // for production wire up SMTP.
        options.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp));
    });

builder.Services.AddRazorPages();

// Development-only OTP dispatcher (prints codes to the console).
// Comment out if you configured UseSmtpOtpDispatcher above.
// builder.Services.AddSingleton<IOtpDispatcher, ConsoleOtpDispatcher>();

var app = builder.Build();

// Auto-create the User Management database schema (SQLite file + tables).
// Storage is document-based — no EF Core migrations required.
var schema = app.Services.GetRequiredService<IDatabaseSchema>();
await schema.CreateIfNotExistsAsync();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // handles authentication middleware
app.UseAuthorization();
app.MapRazorPages();

app.Run();

// ... your existing Config class stays the same ...
```

## 3. OTP Dispatcher

The passwordless OTP flow needs an `IOtpDispatcher` to actually deliver the one-time codes.

**Development** — codes printed to the console:

```csharp
builder.Services.AddSingleton<IOtpDispatcher, ConsoleOtpDispatcher>();
```

**Production** — send via SMTP (configured inside the `AddUserManagement` lambda as shown above):

```csharp
options.UseSmtpOtpDispatcher(x =>
{
    x.Host = "smtp.example.com";
    x.Port = 587;
    x.Username = "noreply@example.com";
    x.Password = "secret";
    x.FromAddress = "noreply@example.com";
});
```

Add the matching `Smtp` section to `appsettings.json` when binding from configuration:

```json
"Smtp": {
  "Host": "smtp.example.com",
  "Port": 587,
  "Username": "noreply@example.com",
  "Password": "secret",
  "FromAddress": "noreply@example.com"
}
```

## Summary / Checklist

- [x] `Duende.UserManagement.IdentityServer8` package added
- [x] `Duende.Storage.Sqlite` package added
- [x] `AddUserManagement(options => { ... })` chained on the IdentityServer builder
- [x] `options.AddSqliteStore("Data Source=users.db")` **inside** the lambda
- [x] An `IOtpDispatcher` registered (console for dev, SMTP for prod)
- [x] `await schema.CreateIfNotExistsAsync()` called at startup to create the SQLite schema

Because storage is document-based, there are **no EF Core migrations** to run — `CreateIfNotExistsAsync()` handles schema creation automatically the first time the app runs.
