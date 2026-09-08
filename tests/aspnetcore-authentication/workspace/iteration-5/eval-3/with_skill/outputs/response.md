To accept **both** JWT access tokens and reference (opaque) tokens on the same `Bearer` scheme, use the Duende JWT bearer extensions: configure `AddJwtBearer` as the primary scheme, and forward anything that isn't a JWT to an introspection handler. Duende ships a ready-made selector for exactly this.

Add the Duende package:

```xml
<PackageReference Include="Duende.AspNetCore.Authentication.JwtBearer" Version="3.0.0" />
```

`Program.cs`:

```csharp
using Duende.AspNetCore.Authentication.JwtBearer; // Selector
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    // Handler #1 — validates JWT access tokens locally
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";

        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = false, // scope-based checks instead, if desired
            NameClaimType = "name",
            RoleClaimType = "role"
        };

        // If the incoming token is NOT a JWT (i.e. a reference/opaque token),
        // forward it to the "introspection" handler below.
        options.ForwardDefaultSelector = Selector.ForwardReferenceToken("introspection");
    })
    // Handler #2 — validates reference tokens against the introspection endpoint
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";

        // The API authenticates to the introspection endpoint with its own credentials
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";

        options.NameClaimType = "name";
        options.RoleClaimType = "role";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/products", () => Results.Ok())
    .RequireAuthorization();

app.Run();
```

### How it works

1. Every request hits the `Bearer` (JWT) handler first.
2. `Selector.ForwardReferenceToken("introspection")` inspects the token format. If it looks like a JWT it is validated locally by the JWT handler; if it's a reference token it is **forwarded** to the `introspection` handler.
3. `AddOAuth2Introspection` calls IdentityServer's `/connect/introspect` endpoint, authenticating with the API's `ClientId` / `ClientSecret` (`catalog-api` / `api-secret`), to validate the opaque token and return its claims.
4. Two named scheme handlers are registered — `Bearer` (JWT) and `introspection` — but callers only ever target the `Bearer` scheme.

`MapInboundClaims = false` on the JWT handler keeps the JWT claim names intact, matching the introspection handler which already returns raw claim names. `AddOAuth2Introspection` comes from the `Duende.AccessTokenManagement.OpenIdConnect` / IdentityModel introspection package.
