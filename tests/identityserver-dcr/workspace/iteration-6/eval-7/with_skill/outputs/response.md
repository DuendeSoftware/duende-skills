# Hosting DCR in a separate application

DCR can run in its own app that trusts your IdentityServer at `https://identity.example.com`.

```bash
dotnet new web -n DcrHost
dotnet add package Duende.IdentityServer.Configuration
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

## Program.cs of the DCR host
```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServerConfiguration(options =>
{
    options.IdentityServerBaseUrl = "https://identity.example.com";
})
.AddClientConfigurationStore();   // EF store, same DB as IdentityServer

builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
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

app.MapDynamicClientRegistration().RequireAuthorization("dcr");

app.Run();
```

## Key points
- **Shared data**: the DCR host must write to the same database IdentityServer reads from (EF configuration store, or a shared data layer). An in-memory store can't work across two processes, so registered clients would never be visible to IdentityServer. Configure `AddConfigurationStore(...)` in IdentityServer and `AddClientConfigurationStore()` in the host with the same connection.
- **Authority**: callers get tokens from `https://identity.example.com` (your `dcr.manager` client with the `IdentityServer.Configuration` scope); the DCR host validates them via `Authority`. Ensure the audience matches (define an `ApiResource` for the scope) .
- **Remove the DCR mapping from the main IdentityServer** (no `MapDynamicClientRegistration()` there) so there's a single entry point.
- Requires a Business Edition (or higher) license.
- Secure with HTTPS, add a custom validator for grant types/PKCE/redirect URIs, and store secrets hashed.
