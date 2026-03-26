# Combined JWT + Reference Token Validation

Here's how to configure your API to accept both JWT access tokens and reference (opaque) tokens:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;

        // Forward reference tokens to the introspection handler
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

The `Duende.AspNetCore.Authentication.JwtBearer` package provides `Selector.ForwardReferenceToken()` which inspects the incoming token format. JWT tokens (starting with `eyJ`) are validated locally by the JWT handler. Reference tokens (opaque strings) are forwarded to the `introspection` scheme, which calls IdentityServer's introspection endpoint to validate them.

This gives you two authentication scheme handlers:
1. **JWT Bearer** (`Bearer`) — validates self-contained JWTs locally
2. **OAuth2 Introspection** (`introspection`) — validates reference tokens via the introspection endpoint using the API's client credentials
