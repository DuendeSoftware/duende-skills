# Combined JWT + Reference Token Validation

To support both JWT access tokens and reference (opaque) tokens, you need to configure both a JWT Bearer handler and an OAuth2 introspection handler, with automatic forwarding based on token format. Install the `Duende.AspNetCore.Authentication.JwtBearer` package which provides the `Selector.ForwardReferenceToken` helper.

Here's the updated `Program.cs`:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";

        // Disable claim type mapping
        options.MapInboundClaims = false;

        // The Duende JWT handler can forward to introspection for reference tokens
        // Reference tokens are opaque (not in JWT format), so they can't be validated locally
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

app.MapGet("/", () => "Hello World!");

app.Run();
```

## How It Works

1. **JWT Bearer handler** (`"Bearer"` scheme): Validates self-contained JWT access tokens locally using the signing keys from the authority's JWKS endpoint.

2. **ForwardDefaultSelector with `Selector.ForwardReferenceToken`**: This inspects the incoming token. If the token is not a valid JWT (i.e., it's a reference/opaque token), it forwards the authentication request to the `"introspection"` scheme instead.

3. **OAuth2 Introspection handler** (`"introspection"` scheme): Sends the opaque token to IdentityServer's introspection endpoint (`/connect/introspect`) along with the API's `ClientId` and `ClientSecret` to validate the token server-side.

This setup gives you the best of both worlds:
- **JWT tokens** are validated locally (fast, no network call)
- **Reference tokens** are validated via introspection (supports revocation, but requires a network call)

The `Selector.ForwardReferenceToken()` method is provided by the `Duende.AspNetCore.Authentication.JwtBearer` NuGet package. Make sure to add it to your project:

```xml
<PackageReference Include="Duende.AspNetCore.Authentication.JwtBearer" Version="7.0.0" />
```
