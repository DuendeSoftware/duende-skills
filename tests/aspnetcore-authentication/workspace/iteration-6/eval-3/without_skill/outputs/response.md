Use JWT bearer plus the OAuth 2.0 token introspection handler (`Duende.AspNetCore.Authentication.OAuth2Introspection`, or `IdentityModel.AspNetCore.OAuth2Introspection`), and a policy scheme that selects the handler based on whether the token looks like a JWT.

```xml
<PackageReference Include="Duende.AspNetCore.Authentication.OAuth2Introspection" Version="6.*" />
```

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddPolicyScheme("token", "JWT or reference", options =>
    {
        options.ForwardDefaultSelector = ctx =>
        {
            var header = ctx.Request.Headers.Authorization.ToString();
            if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var token = header["Bearer ".Length..].Trim();
                // JWTs have two dots
                if (token.Count(c => c == '.') == 2)
                    return "jwt";
            }
            return "introspection";
        };
    })
    .AddJwtBearer("jwt", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "catalog-api";
        options.MapInboundClaims = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
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
app.MapGet("/secure", (HttpContext c) => c.User.Claims.Select(x => new { x.Type, x.Value }))
   .RequireAuthorization();

app.Run();
```

The secret should come from user-secrets or a vault in real deployments.
