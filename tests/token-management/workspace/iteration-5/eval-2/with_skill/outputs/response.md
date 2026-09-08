# User Token Management for an ASP.NET Core Web App

This wires up cookie + OIDC authentication, user token management, an `invoices` HTTP client that attaches the logged-in user's access token, and refresh-token revocation on sign-out.

## Package

```bash
dotnet add package Duende.AccessTokenManagement.OpenIdConnect
```

## `Program.cs`

```csharp
using Duende.AccessTokenManagement.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Cookie.Name = "web";

        // ✅ Revoke the refresh token at the authorization server on sign-out
        options.Events.OnSigningOut = async e =>
        {
            await e.HttpContext.RevokeRefreshTokenAsync();
        };
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.ResponseMode = "query";

        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.Scope.Add("invoice");
        options.Scope.Add("offline_access"); // ← required to receive refresh tokens

        options.GetClaimsFromUserInfoEndpoint = true;
        options.MapInboundClaims = false;

        // ✅ REQUIRED — persists access + refresh tokens into the auth session
        options.SaveTokens = true;
    });

// ✅ Registers user token management services
builder.Services.AddOpenIdConnectAccessTokenManagement();

// ✅ Named HTTP client that automatically attaches the user's access token,
//    refreshing silently via the refresh token when expired
builder.Services.AddUserAccessTokenHttpClient(
    "invoices",
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/invoices/");
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/invoices", async (IHttpClientFactory factory, CancellationToken ct) =>
{
    // ✅ Token attached automatically — no manual token code
    var client = factory.CreateClient("invoices");
    var response = await client.GetAsync("list", ct);
    return Results.Ok(await response.Content.ReadAsStringAsync(ct));
}).RequireAuthorization();

app.Run();
```

## Key points

| Requirement | How it's satisfied |
|---|---|
| Cookie + OIDC auth against `https://sts.example.com` | `AddCookie("cookie")` + `AddOpenIdConnect("oidc")` with `Authority` set |
| `openid profile email invoice offline_access` scopes | Added explicitly to `options.Scope` |
| `SaveTokens = true` | Set on the OIDC handler — **mandatory** for token management to read/refresh tokens |
| Named `invoices` client attaching the user token | `AddUserAccessTokenHttpClient("invoices", ...)` with `BaseAddress` |
| Refresh tokens revoked on sign-out | `OnSigningOut` calls `e.HttpContext.RevokeRefreshTokenAsync()` |

**Why `SaveTokens = true` matters:** without it the OIDC handler never stores the access/refresh tokens in the authentication session, and `AddOpenIdConnectAccessTokenManagement()` throws `InvalidOperationException` at runtime when it tries to read them. This is the single most common misconfiguration.

**Why `offline_access`:** the authorization server only issues a refresh token when this scope is requested. Without it the access token simply expires and the user is forced to re-authenticate.

Don't cache the token yourself in a field or static — call `factory.CreateClient("invoices")` on every request and let the library serve from its cache and refresh transparently.
