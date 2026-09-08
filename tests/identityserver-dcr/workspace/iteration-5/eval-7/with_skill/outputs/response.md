# Hosting DCR in a separate application

DCR can run as its own host, separate from IdentityServer. The separate host runs the `Duende.IdentityServer.Configuration` services **without** running IdentityServer itself — it only exposes the `/connect/dcr` endpoint and writes clients into the shared client store.

Key points for a separate host:

- Call `AddIdentityServerConfiguration(...)` and point `IdentityServerBaseUrl` at your main IdentityServer.
- **Do not** call `AddIdentityServer()` — this host is not an IdentityServer instance.
- Authenticate callers with JWT bearer against the main IdentityServer, and require authorization on the endpoint.
- The client configuration store must write to the **same database** IdentityServer reads from, so registered clients are usable.

## `Program.cs` for the separate DCR host

```csharp
using Duende.IdentityServer.Configuration.EntityFramework;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// DCR services — point at the main IdentityServer (NO AddIdentityServer() here)
builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
})
.AddClientConfigurationStore(); // EF store backed by the SAME database IdentityServer uses

builder.Services.AddDbContext<ConfigurationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("ConfigurationDb"))); // shared DB

// Authenticate DCR callers against the main IdentityServer
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience  = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];
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

// Only the DCR endpoint is exposed here — secured
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## Why each piece matters

- **`AddIdentityServerConfiguration(options => options.IdentityServerBaseUrl = "https://identity.example.com")`** tells the DCR host where the main IdentityServer lives (used when generating registration URIs and resolving issuer metadata).
- **No `AddIdentityServer()`** — the separate host is *not* an IdentityServer; it hosts only the configuration/DCR endpoint. Adding IdentityServer here would spin up a second, unwanted token service.
- **JWT bearer with `Authority = "https://identity.example.com"`** — access tokens presented to the DCR endpoint are validated against the main IdentityServer's keys.
- **Shared client store** — `AddClientConfigurationStore()` must point at the **same database** IdentityServer reads clients from. If the DCR host writes to a different database, registered clients won't be visible to IdentityServer at token time.

This gives you a standalone DCR host that registers clients into IdentityServer's store while keeping DCR concerns out of the main IdentityServer process.
