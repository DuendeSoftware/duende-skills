# Configuring a Production SMTP OTP Dispatcher

For production, replace the development console dispatcher with the built-in **SMTP OTP dispatcher**. It's configured with `UseSmtpOtpDispatcher()` **inside the `AddUserManagement()` options lambda** — the same place your storage is configured.

## Program.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.UserManagement;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        options.AddSqliteStore("Data Source=users.db"); // or your prod store

        // Production email OTP delivery via SMTP
        options.UseSmtpOtpDispatcher(smtp =>
        {
            smtp.Host = "smtp.example.com";
            smtp.Port = 587;                       // 587 = STARTTLS
            smtp.Username = "noreply@example.com";
            smtp.Password = "super-secret";        // pull from secrets, see below
            smtp.FromAddress = "noreply@example.com";
        });
    });

builder.Services.AddRazorPages();

var app = builder.Build();
// ... schema.CreateIfNotExistsAsync(), UseIdentityServer(), etc.
```

## Bind from Configuration (recommended)

Keep credentials out of source. Add an `Smtp` section to `appsettings.json` (and override secrets via user-secrets, environment variables, or a vault in production):

```json
"Smtp": {
  "Host": "smtp.example.com",
  "Port": 587,
  "Username": "noreply@example.com",
  "FromAddress": "noreply@example.com"
}
```

```csharp
options.UseSmtpOtpDispatcher(smtp =>
    builder.Configuration.GetSection("Smtp").Bind(smtp));
```

Set the password out-of-band, e.g. `dotnet user-secrets set "Smtp:Password" "..."` locally or `Smtp__Password` as an environment variable in production.

## Important: Don't Use ConsoleOtpDispatcher in Production

```csharp
// ❌ Development only — prints OTP codes to the console, never emails them.
builder.Services.AddSingleton<IOtpDispatcher, ConsoleOtpDispatcher>();
```

`ConsoleOtpDispatcher` only writes the one-time code to the app's console/log output. In production your users would never receive their codes (and printing OTPs to logs is a security risk). Use `UseSmtpOtpDispatcher()` — or a custom `IOtpDispatcher` backed by a transactional email provider — for any real deployment.

## Key Points

- `UseSmtpOtpDispatcher()` goes **inside** `AddUserManagement(options => { ... })`.
- Configure at minimum: **Host**, **Port**, and **FromAddress** (plus Username/Password for authenticated relays).
- Prefer binding from configuration so credentials stay out of code.
- Never ship `ConsoleOtpDispatcher` to production.
