# BFF v4 Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = builder.Configuration["Oidc:Authority"];   // https://idp.example.com
        options.ClientId = builder.Configuration["Oidc:ClientId"];     // spa-bff-client
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens = true;
        options.MapInboundClaims = false;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access"); // refresh tokens
    })
    .ConfigureCookies(options =>
    {
        // Strict if the IDP is same-site; Lax if a cross-site redirect is involved
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();            // after UseRouting, before UseAuthorization
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.Run();
```

Notes:
- v4 auto-configures cookie + OIDC via `ConfigureOpenIdConnect`/`ConfigureCookies`; don't call `AddCookie`/`AddOpenIdConnect` yourself.
- Management endpoints (`/bff/login`, `/bff/logout`, `/bff/user`, `/bff/backchannel-logout`) are registered automatically in v4; no `MapBffManagementEndpoints()`.
- `SaveTokens = true` and `offline_access` are required for token management/refresh.
- Keep the secret out of appsettings in production (user-secrets/vault).
- React side: log in with `window.location.href = '/bff/login'`, call `/bff/user` with `X-CSRF: 1`, and send that header on all API calls.
