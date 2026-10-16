Use the JWT bearer handler as the default and forward reference tokens to the introspection handler.

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;   // Selector (package: Duende.AspNetCore.Authentication.JwtBearer)

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.MapInboundClaims = false;

        // Reference (opaque) tokens are forwarded to the introspection scheme
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
app.MapGet("/secure", () => "ok").RequireAuthorization();

app.Run();
```

Notes:
- `Selector.ForwardReferenceToken` inspects the token: JWT-shaped tokens are validated locally by the JWT handler, others go to introspection using the API resource's ID and secret.
- `MapInboundClaims = false` keeps claim names like `sub` intact.
- Add the `Duende.AspNetCore.Authentication.JwtBearer` and OAuth2 introspection packages to the csproj; keep the secret in user-secrets/vault rather than source.
- Authentication middleware before authorization.
