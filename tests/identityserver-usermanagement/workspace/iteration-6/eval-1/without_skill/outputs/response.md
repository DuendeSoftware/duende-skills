I'm not certain of the exact API surface of Duende User Management, so treat names below as best-effort and verify against the docs.

**Packages**
```
dotnet add package Duende.UserManagement
dotnet add package Duende.UserManagement.Sqlite   # storage provider (name may differ)
```

**Program.cs**
```csharp
builder.Services.AddUserManagement(options =>
{
    options.Authentication.Otp.Enabled = true;   // email one-time passcode
})
.AddSqliteStore(builder.Configuration.GetConnectionString("UserManagement"));

builder.Services.AddIdentityServer(o => { o.EmitStaticAudienceClaim = true; })
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes);
```
Also register an email sender (for development, a console/logging sender; for production an SMTP/API implementation), and `app.UseAuthentication()` before `UseAuthorization()`.

**appsettings.json**
```json
"ConnectionStrings": { "UserManagement": "Data Source=usermanagement.db" }
```
SQLite files are created on first use; apply any provided migrations/schema creation on startup. Then build a login Razor Page that asks for the email, sends the OTP, and verifies the code.
