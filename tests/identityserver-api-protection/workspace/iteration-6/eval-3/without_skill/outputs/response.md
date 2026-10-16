# Supporting both JWTs and reference tokens

Register a JWT bearer scheme and an introspection scheme, then use a policy scheme that picks one based on the token shape (a JWT has two dots).

```
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package IdentityModel.AspNetCore.OAuth2Introspection
```

```csharp
using IdentityModel.AspNetCore.OAuth2Introspection;
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthentication("smart")
    .AddPolicyScheme("smart", "JWT or reference", options =>
    {
        options.ForwardDefaultSelector = ctx =>
        {
            var auth = ctx.Request.Headers.Authorization.ToString();
            if (auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var token = auth["Bearer ".Length..].Trim();
                if (token.Count(c => c == '.') == 2)
                    return JwtBearerDefaults.AuthenticationScheme;
                return "introspection";
            }
            return JwtBearerDefaults.AuthenticationScheme;
        };
    })
    .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, o =>
    {
        o.Authority = "https://identity.example.com";
        o.Audience = "api1";
        o.MapInboundClaims = false;
        o.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    })
    .AddOAuth2Introspection("introspection", o =>
    {
        o.Authority = "https://identity.example.com";
        o.ClientId = "api1";
        o.ClientSecret = "api1_secret";   // keep in a secret store
        o.EnableCaching = true;
        o.CacheDuration = TimeSpan.FromMinutes(5);
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

Notes: the `api1` resource needs the secret in IdentityServer; JWTs are validated locally via JWKS, reference tokens via the introspection endpoint; both yield a ClaimsPrincipal so authorization policies work identically.
