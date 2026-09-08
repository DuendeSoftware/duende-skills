# Setting up Duende BFF to secure a React SPA

Here's a full `Program.cs` that wires up Duende BFF with OpenID Connect against your IdP. The BFF holds the tokens server-side and hands the browser only a secure, HTTP-only cookie.

First make sure the package is referenced (it already is in your csproj). You'll configure cookie + OpenID Connect authentication and then add the BFF services.

```csharp
using Duende.Bff;

var builder = WebApplication.CreateBuilder(args);

// BFF services
builder.Services.AddBff();

// Authentication: cookie for the session, OIDC to talk to the IdP
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
        options.DefaultSignOutScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = builder.Configuration["Oidc:Authority"];       // https://idp.example.com
        options.ClientId = builder.Configuration["Oidc:ClientId"];         // spa-bff-client
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"]; // secret
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.GetClaimsFromUserInfoEndpoint = true;
        options.SaveTokens = true;   // keep tokens in the session
        options.MapInboundClaims = false;

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("offline_access");  // needed for refresh tokens
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// BFF management endpoints: /bff/login, /bff/logout, /bff/user
app.MapBffManagementEndpoints();

app.MapGet("/", () => "Hello World");

app.Run();
```

## Key points

- **`offline_access`** is included so the IdP issues a refresh token — the BFF can then silently renew the access token when it expires.
- **`SaveTokens = true`** stores the tokens in the authentication session so the server can use them for downstream API calls.
- **`__Host-` cookie prefix + `Secure` + `HttpOnly`** keep the session cookie locked to your origin and invisible to JavaScript.
- **`MapBffManagementEndpoints()`** exposes `/bff/login`, `/bff/logout` and `/bff/user`, which your React app uses to start login, sign out, and check the current user.

## React side

Login and logout are full-page navigations (they involve redirects to the IdP), so trigger them with `window.location`, not `fetch`:

```javascript
// start login
window.location.href = "/bff/login";

// check current user on app start
const res = await fetch("/bff/user", { headers: { "X-CSRF": "1" } });
const user = res.ok ? await res.json() : null;
```

That gives you a working BFF-secured React SPA.
