# Adding Duende User Management with Email OTP and SQLite

## 1. Add NuGet Packages

```bash
dotnet add package Duende.UserManagement.IdentityServer8
dotnet add package Duende.Storage.Sqlite
```

## 2. Updated Program.cs

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Duende.UserManagement;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddUserManagement(options =>
    {
        // Storage — SQLite
        options.AddSqliteStore("Data Source=users.db");

        // OTP delivery — use SMTP for production, Console for dev
        options.UseSmtpOtpDispatcher(smtp =>
            builder.Configuration.GetSection("Smtp").Bind(smtp));
    });

builder.Services.AddRazorPages();

var app = builder.Build();

// Ensure database schema exists (document-based, no EF migrations needed)
var schema = app.Services.GetRequiredService<IDatabaseSchema>();
await schema.CreateIfNotExistsAsync();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();

// Configuration classes (unchanged)
public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "web",
            ClientName = "Web App",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "email", "api1" }
        }
    ];
}
```

## 3. Configure SMTP in appsettings.json

```json
{
  "Smtp": {
    "Host": "smtp.example.com",
    "Port": 587,
    "Username": "noreply@example.com",
    "Password": "your-password",
    "FromAddress": "noreply@example.com"
  }
}
```

For development, you can replace the SMTP dispatcher with a console logger:

```csharp
// In development only:
builder.Services.AddSingleton<IOtpDispatcher, ConsoleOtpDispatcher>();
```

## Key Points

- `AddUserManagement()` is chained on the IdentityServer builder, with all configuration (storage, OTP) inside the options lambda.
- `AddSqliteStore()` configures document-based SQLite storage — no EF Core migrations needed.
- `IDatabaseSchema.CreateIfNotExistsAsync()` auto-creates the schema on first run.
- The default authentication flow is passwordless OTP via email, which requires an `IOtpDispatcher` implementation.
