# Running DCR as a separate host

You can run the Dynamic Client Registration endpoint in its own ASP.NET Core application, separate from your IdentityServer at `https://identity.example.com`. The DCR host uses the `Duende.IdentityServer.Configuration` package and exposes only the registration endpoint; it validates incoming tokens against the main IdentityServer.

## `Program.cs` for the DCR host

```csharp
using Duende.IdentityServer.Configuration.EntityFramework;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// DCR / configuration services (this host does NOT run IdentityServer itself)
builder.Services.AddIdentityServerConfiguration();

// Persist registered clients through the configuration store,
// pointing at the SAME database the main IdentityServer uses.
builder.Services.AddClientConfigurationStore();
builder.Services.AddDbContext<ConfigurationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("SharedIdentityDb")));

// Validate access tokens issued by the main IdentityServer
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com"; // the main IdentityServer
        options.Audience  = "IdentityServer.Configuration";
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## Notes

- **Separate concern**: this host only exposes `/connect/dcr`. It authenticates callers with JWT bearer, using the main IdentityServer (`https://identity.example.com`) as the token `Authority`, so tokens are validated against its signing keys and discovery document.
- **Shared client store**: because registration happens here but tokens are issued by the main IdentityServer, both applications must read/write the **same** client database. Point the configuration store's `DbContext` connection string at the same database IdentityServer uses; otherwise newly registered clients won't be visible when clients request tokens.
- **Authorization is mandatory**: `RequireAuthorization("dcr")` ensures only callers with a valid token and the `IdentityServer.Configuration` scope can register clients.
- Configure the DCR host's public base URL / issuer settings (e.g. in `appsettings.json`) so any registration URIs it returns resolve correctly relative to your deployment.

Deploy this as its own service (e.g. `https://dcr.example.com`) behind TLS, sharing the client database with `https://identity.example.com`.
