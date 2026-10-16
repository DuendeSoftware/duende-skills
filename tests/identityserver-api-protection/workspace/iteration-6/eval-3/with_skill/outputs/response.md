# One API accepting JWTs and reference tokens

Use `ForwardReferenceToken` from `Duende.AspNetCore.Authentication.JwtBearer`: JWT bearer is the main scheme, and tokens without a dot are forwarded to the introspection handler.

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];

        // No dot => reference token => forward to "introspection"
        options.ForwardDefaultSelector = Selector.ForwardReferenceToken("introspection");
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "api1";
        options.ClientSecret = "api1_secret";
    });

builder.Services.AddAuthorization(o =>
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/data", () => Results.Ok(new { message = "Protected" }));
app.Run();
```

## How it works
- Token **contains a dot** → JWT (header.payload.signature) → validated locally by `AddJwtBearer` (signature via JWKS, `at+jwt` type, audience).
- **No dot** → opaque reference token → forwarded to `AddOAuth2Introspection`.

## Pitfalls
- The string passed to `ForwardReferenceToken("introspection")` must **exactly match** the scheme name in `AddOAuth2Introspection("introspection", ...)`.
- IdentityServer's `ApiResource("api1")` needs `ApiSecrets = { new Secret("api1_secret".Sha256()) }`, otherwise introspection fails with 401.
- Keep `ValidTypes = ["at+jwt"]` to prevent JWT confusion attacks.
- Both paths produce a `ClaimsPrincipal`, so the same scope policies work for both.
