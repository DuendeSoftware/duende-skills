# Problems in this code

1. **No default/challenge scheme** – `AddAuthentication()` sets neither, so cookie ↔ OIDC isn't wired: set `DefaultScheme = "cookie"`, `DefaultChallengeScheme = "oidc"`.
2. **Missing `SaveTokens = true`** – tokens are never persisted in the session, so `AddOpenIdConnectAccessTokenManagement` throws `InvalidOperationException` when it needs a user token.
3. **Missing `offline_access`** – no refresh token; the access token expires and the user must log in again.
4. **No refresh-token revocation on sign-out** – cookie needs `OnSigningOut` → `await e.HttpContext.RevokeRefreshTokenAsync()`.
5. **`AddClientCredentialsTokenHandler("catalog.client")` with no definition** – `AddClientCredentialsTokenManagement().AddClient("catalog.client", ...)` is never registered, so the handler can't resolve the client. Also the string should be `ClientCredentialsClientName.Parse("catalog.client")`.
6. **No resiliency handler** – a 401 from an expired token (or DPoP nonce) is returned straight to the caller; add `.AddDefaultAccessTokenResiliency()` before the token handler (or use `AddClientCredentialsHttpClient`, which includes it).
7. **Manual token caching in `_cachedToken`** – double caching: never invalidated, so after expiry you serve a stale token (and if the service is a singleton, one user's token leaks to others). Call the manager on every request; it serves from cache (v4 `HybridCache`).
8. **`GetToken()` without checking `Succeeded`** – it throws when retrieval failed, hiding the real error.
9. **Returning the cached token from `CallApi`** – and it returns the token rather than calling the API; the design is confused.
10. **Hard-coded secret** (`"secret"`) – use configuration/secret store. (Also no `MapInboundClaims = false` / `GetClaimsFromUserInfoEndpoint` – minor.)
11. **Mixing concerns** – the typed client uses client credentials while the user flow is configured, with no clear intent. If a call should be on behalf of the user, use `AddUserAccessTokenHandler()`.

## Corrected

```csharp
builder.Services.AddAuthentication(o =>
    {
        o.DefaultScheme = "cookie";
        o.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", o =>
    {
        o.Events.OnSigningOut = async e => await e.HttpContext.RevokeRefreshTokenAsync();
    })
    .AddOpenIdConnect("oidc", o =>
    {
        o.Authority = "https://sts.example.com";
        o.ClientId = "webapp";
        o.ClientSecret = builder.Configuration["Oidc:Secret"];
        o.ResponseType = "code";
        o.Scope.Add("openid");
        o.Scope.Add("api1");
        o.Scope.Add("offline_access");
        o.SaveTokens = true;
    });

builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", c =>
    {
        c.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        c.ClientId = ClientId.Parse("catalog");
        c.ClientSecret = ClientSecret.Parse(builder.Configuration["Catalog:Secret"]!);
        c.Scope = Scope.Parse("catalog");
    });

builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddDefaultAccessTokenResiliency()
    .AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("catalog.client"));
```

```csharp
public async Task<string> CallApi(CancellationToken ct)
{
    var result = await _tokenManager.GetAccessTokenAsync(ClientCredentialsClientName.Parse("catalog.client"), ct: ct);
    if (!result.Succeeded) throw new InvalidOperationException("Token acquisition failed");
    return result.GetToken().AccessToken.ToString();   // no field caching
}
```
