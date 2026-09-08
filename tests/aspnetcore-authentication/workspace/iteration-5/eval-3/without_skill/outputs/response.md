You can support both token types by running two authentication handlers and forwarding requests that carry an opaque (reference) token to an introspection handler. The trick is that a JWT is three Base64URL segments separated by dots, whereas a reference token is not — so you can detect which is which and use `ForwardDefaultSelector`.

You'll need the OAuth2 introspection package:

```xml
<PackageReference Include="IdentityModel.AspNetCore.OAuth2Introspection" Version="6.2.0" />
```

`Program.cs`:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            NameClaimType = "name",
            RoleClaimType = "role"
        };

        // If the token is not a JWT (a reference/opaque token), forward it
        // to the introspection handler.
        options.ForwardDefaultSelector = context =>
        {
            var authHeader = (string?)context.Request.Headers.Authorization;
            if (authHeader?.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) == true)
            {
                var token = authHeader["Bearer ".Length..].Trim();
                // A JWT has exactly two dots (header.payload.signature)
                if (token.Count(c => c == '.') != 2)
                {
                    return "introspection";
                }
            }
            return null; // handle as JWT
        };
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

app.MapGet("/products", () => Results.Ok())
    .RequireAuthorization();

app.Run();
```

### How it works

- **`AddJwtBearer("Bearer", ...)`** validates JWTs locally using the signing keys downloaded from the authority.
- **`ForwardDefaultSelector`** inspects the incoming bearer token. If it doesn't have the JWT `header.payload.signature` shape, it forwards the request to the `introspection` scheme instead.
- **`AddOAuth2Introspection("introspection", ...)`** calls the IdentityServer `/connect/introspect` endpoint using the API's `ClientId` and `ClientSecret` (`catalog-api` / `api-secret`) to validate the opaque token.
- Two scheme handlers are registered, but clients always send tokens to the single `Bearer` scheme.

This gives you a single `[Authorize]` surface that accepts either token format.
