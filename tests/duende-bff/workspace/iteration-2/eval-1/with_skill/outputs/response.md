Here's the complete `Program.cs` setup for Duende BFF v4 securing a React SPA:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority = "https://idp.example.com";
        options.ClientId = "spa-bff-client";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens = true;
        options.MapInboundClaims = false;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access"); // Required for refresh tokens
    })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();           // Adds CSRF anti-forgery enforcement middleware
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.Run();
```

Key points about this setup:

1. **`AddBff()` with fluent API** — BFF v4 uses `ConfigureOpenIdConnect` and `ConfigureCookies` instead of manually calling `AddAuthentication().AddCookie().AddOpenIdConnect()`. The fluent API auto-configures authentication schemes with recommended defaults.

2. **`offline_access` scope** — This is critical for obtaining a refresh token so BFF can automatically renew expired access tokens via the integrated `Duende.AccessTokenManagement`.

3. **Middleware order** — The order `UseRouting() → UseAuthentication() → UseBff() → UseAuthorization()` is mandatory. `UseBff()` must come after `UseAuthentication()` but before `UseAuthorization()`. Incorrect ordering silently disables anti-forgery enforcement.

4. **`SaveTokens = true`** — Without this, OIDC tokens are not stored in the session, and `GetUserAccessTokenAsync()` returns nothing.

5. **Management endpoints** — In v4, `/bff/login`, `/bff/logout`, `/bff/user`, and `/bff/backchannel-logout` are registered automatically by `AddBff()`. You do **not** need to call `MapBffManagementEndpoints()` (that was v3).

6. **`SameSite = Lax`** — Since the IDP (`idp.example.com`) is likely on a different domain than the BFF, `Lax` is needed. `Strict` would cause the post-login session cookie to not be sent on the first cross-site redirect from the IDP.
