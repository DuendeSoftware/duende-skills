# Adding Dynamic Client Registration (DCR) to Duende IdentityServer

DCR lets clients register themselves at the `/connect/dcr` endpoint per RFC 7591. A few things to know up front:

- DCR lives in a **separate NuGet package** (`Duende.IdentityServer.Configuration`), not in `Duende.IdentityServer`.
- It requires a **Business Edition or higher license**. Community Edition does not support DCR.
- You must **secure the endpoint** — never expose `/connect/dcr` unauthenticated.

## 1. Add the NuGet package

```bash
dotnet add package Duende.IdentityServer.Configuration
```

Or add it to `IdentityServer.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
  <PackageReference Include="Duende.IdentityServer.Configuration" Version="8.0.0" />
  <PackageReference Include="Serilog.AspNetCore" Version="8.0.3" />
</ItemGroup>
```

## 2. Register the DCR services

Call `AddIdentityServerConfiguration()` on the service collection, alongside your existing `AddIdentityServer()` registration:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */);

// Register DCR services
builder.Services.AddIdentityServerConfiguration();
```

## 3. Map the DCR endpoint (with authorization)

`MapDynamicClientRegistration()` is an **endpoint-routing extension from the `Duende.IdentityServer.Configuration` package**. Place it in the endpoint-routing/pipeline section alongside `UseIdentityServer()` — in your `Program.cs` that is right where you map Razor Pages. Secure it with `RequireAuthorization()` so only authorized callers can register clients.

Here is your updated `Program.cs`:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1"),
        new ApiScope("api2", "API 2"),
        new ApiScope("IdentityServer.Configuration", "IdentityServer Configuration API")
    })
    .AddInMemoryClients(/* ... your existing clients ... */);

// 1. Register DCR services
builder.Services.AddIdentityServerConfiguration();

// 2. Authentication + authorization for the DCR endpoint
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

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();

// 3. Map the DCR endpoint — secured
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

## Summary of the required pieces

| Step | Call | Where |
| ---- | ---- | ----- |
| Package | `Duende.IdentityServer.Configuration` | `.csproj` |
| Services | `AddIdentityServerConfiguration()` | service registration |
| Endpoint | `MapDynamicClientRegistration()` | endpoint routing, next to `UseIdentityServer()` |
| Security | `.RequireAuthorization("dcr")` | on the mapped endpoint |

Both `AddIdentityServerConfiguration()` and `MapDynamicClientRegistration()` are required. Remember: this feature needs a **Business Edition or higher license**, and the endpoint should always be behind an authorization policy.

Docs: https://docs.duendesoftware.com/identityserver/configuration/dcr
