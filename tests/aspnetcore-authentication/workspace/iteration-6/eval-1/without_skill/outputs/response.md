## Program.cs

```csharp
using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

// Prevent mapping of JWT claims (sub, name) to long XML/WS-* URIs
JwtSecurityTokenHandler.DefaultMapInboundClaims = false;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie()
.AddOpenIdConnect(options =>
{
    var cfg = builder.Configuration.GetSection("Authentication");
    options.Authority = cfg["Authority"];
    options.ClientId = cfg["ClientId"];
    options.ClientSecret = cfg["ClientSecret"];
    options.ResponseType = OpenIdConnectResponseType.Code;
    options.UsePkce = true;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("api1");

    options.SaveTokens = true;
    options.GetClaimsFromUserInfoEndpoint = true;

    // Also disable mapping on the handler instance (newer JsonWebTokenHandler)
    options.MapInboundClaims = false;
    options.TokenValidationParameters.NameClaimType = "name";
    options.TokenValidationParameters.RoleClaimType = "role";
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

Notes:
- `JwtSecurityTokenHandler.DefaultMapInboundClaims = false` and `options.MapInboundClaims = false` keep claims as `sub`, `name`, etc. rather than `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/...`.
- Code flow with PKCE is used; the secret is read from configuration (use user-secrets or a vault in production rather than appsettings).
- `UseAuthentication` must come before `UseAuthorization`.
