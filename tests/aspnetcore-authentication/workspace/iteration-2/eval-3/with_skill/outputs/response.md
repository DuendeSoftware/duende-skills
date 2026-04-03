# Combined JWT + Reference Token Validation

Here's the updated `Program.cs` that supports both JWT access tokens and reference (opaque) tokens using the Duende JWT handler's `ForwardDefaultSelector`:

```csharp
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = "catalog-api",
            NameClaimType = "name",
            RoleClaimType = "role"
        };

        // Use the Duende selector to forward reference tokens to the introspection handler
        options.ForwardDefaultSelector = Selector.ForwardReferenceToken("introspection");
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!")
    .RequireAuthorization();

app.Run();
```

## How This Works

This configuration registers **two authentication scheme handlers**:

1. **JWT Bearer (`"Bearer"`)** — Handles self-contained JWT access tokens by validating the signature using keys from the IdentityServer JWKS endpoint.
2. **OAuth2 Introspection (`"introspection"`)** — Handles reference (opaque) tokens by calling the IdentityServer introspection endpoint to validate them server-side.

### The ForwardDefaultSelector

The key to making this work is `Selector.ForwardReferenceToken("introspection")` from the `Duende.AspNetCore.Authentication.JwtBearer` package. This selector inspects the incoming token:

- If the token **looks like a JWT** (contains dots and can be parsed as a JWT), it is handled by the JWT Bearer handler normally.
- If the token is an **opaque string** (reference token), the request is forwarded to the `"introspection"` scheme for validation via the introspection endpoint.

### Introspection Authentication

The `AddOAuth2Introspection` handler authenticates to the introspection endpoint using the API's `ClientId` and `ClientSecret`. The introspection endpoint returns whether the token is active and its associated claims.

### Important Notes

- **`MapInboundClaims = false`** is set on the JWT Bearer handler to preserve original claim names.
- You need to install the `Duende.AspNetCore.Authentication.JwtBearer` NuGet package for the `Selector.ForwardReferenceToken` method.
- Reference tokens enable immediate revocation (unlike JWTs which are valid until expiry), but require a network call to IdentityServer for each API request.
