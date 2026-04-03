# Combined JWT + Reference Token Validation

To support both JWT and opaque tokens, you'll need to configure both JWT Bearer and token introspection. Here's an approach:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";
    })
    .AddOAuth2Introspection("Introspection", options =>
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

This sets up two authentication handlers:

1. **JWT Bearer** — Validates self-contained JWT tokens using signing keys from the authority's discovery document.
2. **OAuth2 Introspection** — Validates opaque/reference tokens by calling the token introspection endpoint.

The JWT Bearer handler will be the default since it's registered first. For reference tokens, you would need to configure some kind of scheme selection logic to route requests to the introspection handler when the token isn't a valid JWT.

You could implement a custom `IAuthenticationSchemeProvider` or middleware to detect the token format and select the appropriate scheme. The basic idea is:
- If the token has the JWT format (three base64-encoded parts separated by dots), use JWT Bearer
- Otherwise, forward to the introspection handler

The introspection handler authenticates to the introspection endpoint using the API's client credentials.
