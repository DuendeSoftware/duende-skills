# Accepting both JWTs and reference tokens in one API

The clean way to support both formats behind a single `Bearer` scheme is to let a JWT bearer handler be the default, and **forward reference tokens** to an introspection handler. Duende provides a ready-made selector, `Selector.ForwardReferenceToken`, in the `Duende.AspNetCore.Authentication.JwtBearer` package. It inspects the incoming token: JWTs always contain dots (`header.payload.signature`), reference tokens don't — so tokens without a dot are forwarded to introspection.

## 1. Add the package

```bash
dotnet add package Duende.AspNetCore.Authentication.JwtBearer
```

(This also brings in the introspection handler transitively; if not, add `Duende.AspNetCore.Authentication.OAuth2Introspection` as well.)

## 2. Configure both handlers in `Program.cs`

```csharp
using Duende.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Only accept access-token JWTs; blocks JWT confusion attacks.
        options.TokenValidationParameters.ValidTypes = ["at+jwt"];

        // If the incoming token has no dot, forward it to the "introspection"
        // handler below. The scheme name here MUST match AddOAuth2Introspection.
        options.ForwardDefaultSelector =
            Selector.ForwardReferenceToken("introspection");
    })
    .AddOAuth2Introspection("introspection", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "api1";
        options.ClientSecret = "api1_secret";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## Key points

- **Default scheme is `token` (the JWT handler).** Every request starts there; only dot-less tokens get forwarded.
- **Scheme name consistency is critical.** `Selector.ForwardReferenceToken("introspection")` must reference the exact scheme name you passed to `AddOAuth2Introspection("introspection", ...)`. A typo silently breaks reference-token validation.
- **`ValidTypes = ["at+jwt"]`** stays on the JWT handler so identity tokens can't be replayed as access tokens.
- The introspection handler needs the `ApiResource` to have an `ApiSecret` matching `api1_secret` in IdentityServer.
