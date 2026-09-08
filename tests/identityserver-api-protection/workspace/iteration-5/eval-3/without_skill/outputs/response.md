# Supporting both JWT and reference tokens in a single API

The trick is to register **two authentication handlers** — a JWT bearer handler and an OAuth2 introspection handler — and use a *scheme selector* to route each incoming token to the right one based on its shape. A JWT is three base64url segments separated by dots; a reference token is an opaque string with no dots. So "contains a dot" is a good discriminator.

## 1. Packages

```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
```

## 2. Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Route tokens: if the bearer token has no '.', it's a reference token,
        // so forward to the introspection handler. Otherwise handle as JWT here.
        options.ForwardDefaultSelector = context =>
        {
            var auth = context.Request.Headers.Authorization.ToString();
            if (auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var token = auth["Bearer ".Length..].Trim();
                if (!token.Contains('.'))
                {
                    return "Introspection";
                }
            }
            return "Bearer";
        };
    })
    .AddOAuth2Introspection("Introspection", options =>
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

## Notes

- The **default scheme** is `Bearer` (the JWT handler). The `ForwardDefaultSelector` delegate returns the introspection scheme name only for dot-less tokens.
- The scheme string returned by the selector (`"Introspection"`) must exactly match the scheme registered with `AddOAuth2Introspection("Introspection", ...)`.
- The introspection handler needs the resource's client id/secret, and IdentityServer must have a matching secret on the API resource.
- For JWTs, consider validating the token type to avoid accepting ID tokens as access tokens.

This gives you one `Bearer` entry point that transparently handles both token types.
