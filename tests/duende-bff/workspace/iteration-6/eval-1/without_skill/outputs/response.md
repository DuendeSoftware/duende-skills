# Duende BFF v4 Program.cs

```csharp
using Duende.Bff;
using Duende.Bff.Yarp;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = builder.Configuration["Oidc:Authority"];
        options.ClientId = builder.Configuration["Oidc:ClientId"];
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
        options.ResponseType = "code";
        options.ResponseMode = "query";
        options.GetClaimsFromUserInfoEndpoint = true;
        options.MapInboundClaims = false;
        options.SaveTokens = true;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.MapBffManagementEndpoints();   // /bff/login, /bff/logout, /bff/user, ...

app.MapGet("/", () => "Hello World");

app.MapFallbackToFile("index.html");
app.Run();
```

Notes:
- `AddBff()` registers cookie + OIDC authentication; `ConfigureOpenIdConnect` customises it.
- Don't store the secret in appsettings in production; use user-secrets / a vault.
- `offline_access` gives you a refresh token, which BFF uses to renew access tokens.
- The SPA uses `/bff/login`, `/bff/user` and `/bff/logout`, and must send the `X-CSRF: 1` header on API calls.
- Register `https://localhost:5001/signin-oidc` and `/signout-callback-oidc` at the IdP.
