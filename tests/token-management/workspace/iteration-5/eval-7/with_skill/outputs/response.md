# Code Review: Token Management Problems

There are several correctness and configuration issues here. Walking through them:

## 1. ❌ Missing `SaveTokens = true` on the OIDC handler

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // ... no options.SaveTokens = true
});
```

`AddOpenIdConnectAccessTokenManagement()` reads the user's access/refresh tokens from the authentication session. Without `SaveTokens = true`, the OIDC handler never persists them, and user-token operations throw `InvalidOperationException` at runtime. **This is required for user token management.**

```csharp
options.SaveTokens = true; // ✅ add this
```

## 2. ❌ Missing `offline_access` scope

```csharp
options.Scope.Add("openid");
options.Scope.Add("api1");
// offline_access missing
```

Without `offline_access`, the authorization server issues **no refresh token**. The user's access token will expire and can't be silently refreshed, forcing re-authentication.

```csharp
options.Scope.Add("offline_access"); // ✅ add this
```

## 3. ❌ No refresh-token revocation at sign-out

The cookie handler has no `OnSigningOut` event, so the refresh token stays valid at the authorization server after the user logs out.

```csharp
.AddCookie("cookie", options =>
{
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync(); // ✅
    };
});
```

## 4. ❌ Manual `_cachedToken` field — double-caching

```csharp
private string? _cachedToken;
if (_cachedToken != null) return _cachedToken;
```

The library already caches tokens (v4 `HybridCache`). Caching the token yourself in an instance field means your copy is **never invalidated** — after the real token expires you keep returning a stale one, causing 401s. Never cache tokens in code; call `GetAccessTokenAsync` every time and let the library serve from its cache.

## 5. ❌ `.GetToken()` called without checking `.Succeeded`

```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
var token = result.GetToken(); // throws InvalidOperationException if Succeeded == false
```

In v4, `GetAccessTokenAsync` returns a `TokenResult<T>`. `GetToken()` throws when retrieval failed. Check first:

```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
if (!result.Succeeded)
{
    // log and handle
    return;
}
var token = result.GetToken();
```

## 6. ❌ `AddClientCredentialsTokenHandler` without resiliency

```csharp
builder.Services.AddHttpClient<ApiClient>(...)
    .AddClientCredentialsTokenHandler("catalog.client");
```

Used directly, this has no retry on `401 Unauthorized`, so an expired token (or DPoP nonce challenge) is returned straight to the caller. Add the resiliency handler first:

```csharp
builder.Services.AddHttpClient<ApiClient>(...)
    .AddDefaultAccessTokenResiliency()          // ✅ retries once on 401
    .AddClientCredentialsTokenHandler("catalog.client");
```

*(Note: `AddClientCredentialsHttpClient` bundles this resiliency automatically; the token-handler form does not.)*

---

## Corrected sketch

```csharp
builder.Services.AddAuthentication(options =>
    {
        options.DefaultScheme = "cookie";
        options.DefaultChallengeScheme = "oidc";
    })
    .AddCookie("cookie", options =>
    {
        options.Events.OnSigningOut = async e => await e.HttpContext.RevokeRefreshTokenAsync();
    })
    .AddOpenIdConnect("oidc", options =>
    {
        options.Authority = "https://sts.example.com";
        options.ClientId = "webapp";
        options.ClientSecret = "secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("api1");
        options.Scope.Add("offline_access");
        options.SaveTokens = true;
    });

builder.Services.AddOpenIdConnectAccessTokenManagement();

builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddDefaultAccessTokenResiliency()
    .AddClientCredentialsTokenHandler("catalog.client");
```

And in the service, drop `_cachedToken` entirely — resolve the client from `IHttpClientFactory` (or call `GetAccessTokenAsync` with a `Succeeded` check) on every call.
