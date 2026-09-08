# Migrating your BFF from V3 to V4

Here's your setup migrated to V4 conventions. The main changes:

1. **Auth handler wiring** → replace the manual `AddAuthentication().AddCookie().AddOpenIdConnect()` with `AddBff().ConfigureOpenIdConnect().ConfigureCookies()`. V4 auto-configures the schemes with recommended defaults.
2. **Management endpoints** → **drop** the manual management-endpoint mapping. In V4 the `/bff/login`, `/bff/logout`, and `/bff/user` endpoints are registered automatically by `AddBff()`.
3. **Remote API token type** → `.RequireAccessToken(TokenType.User)` becomes `.WithAccessToken(RequiredTokenType.User)`.
4. **Remote APIs registration** → V4 requires `.AddRemoteApis()` on the BFF builder for `MapRemoteBffApiEndpoint` to work.

## Migrated code

```csharp
using Duende.Bff;
using Duende.Bff.Yarp;

var builder = WebApplication.CreateBuilder(args);

// ✅ V4: AddBff() with fluent OIDC + cookie config replaces manual scheme wiring
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options =>
    {
        // Original OIDC settings preserved
        options.Authority    = "https://identity.example.com";
        options.ClientId     = "spa";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.SaveTokens   = true;
        options.Scope.Add("api1");
    })
    .ConfigureCookies(options =>
    {
        // Original cookie settings preserved
        options.Cookie.Name = "__Host-bff";
        options.Cookie.SameSite = SameSiteMode.Strict;
    })
    .AddRemoteApis();   // ✅ V4 requires this for remote API endpoints

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

// The manual management-endpoint mapping is removed — auto-registered in V4

app.MapRemoteBffApiEndpoint("/api/data", new Uri("https://api.example.com"))
    .WithAccessToken(RequiredTokenType.User);   // ✅ V4 syntax

app.Run();
```

## What changed and why

| V3 | V4 |
|---|---|
| `AddAuthentication().AddCookie("cookie").AddOpenIdConnect("oidc", …)` | `AddBff().ConfigureOpenIdConnect(…).ConfigureCookies(…)` |
| manual management-endpoint mapping call | *(nothing — auto-registered)* |
| `.RequireAccessToken(TokenType.User)` | `.WithAccessToken(RequiredTokenType.User)` || *(implicit remote APIs)* | `.AddRemoteApis()` required |

- Your original OIDC values (`Authority`, `ClientId`, `ClientSecret`, `ResponseType = "code"`, `SaveTokens`, `Scope.Add("api1")`) and cookie settings (`__Host-bff`, `SameSite.Strict`) are carried over unchanged — `ConfigureOpenIdConnect`/`ConfigureCookies` let you tweak the BFF's defaults rather than replacing them.
- Also note: if you had configured session cleanup via the old `EnableSessionCleanup` option, replace it with `.AddSessionCleanupBackgroundProcess()` on the BFF builder (not present in your snippet, but a common V4 migration gotcha).
