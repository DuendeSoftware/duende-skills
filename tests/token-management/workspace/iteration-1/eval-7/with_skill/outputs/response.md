# Code Review: Token Management Issues

Here are all the problems in the provided code:

## Issue 1: Missing `SaveTokens = true` on the OIDC Handler

```csharp
// ❌ Current code — SaveTokens not set (defaults to false)
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    options.ClientId = "webapp";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.Scope.Add("openid");
    options.Scope.Add("api1");
});
```

**Problem**: `SaveTokens` defaults to `false`. Without it, the OIDC handler does not persist the access token and refresh token into the authentication session. `AddOpenIdConnectAccessTokenManagement()` requires these tokens to be stored in the session — it reads them from the authentication properties. Without `SaveTokens = true`, the library throws `InvalidOperationException` at runtime when it tries to read the user's access token.

**Fix**: Add `options.SaveTokens = true;`

## Issue 2: Missing `offline_access` Scope

```csharp
// ❌ Only openid and api1 are requested
options.Scope.Add("openid");
options.Scope.Add("api1");
```

**Problem**: Without requesting the `offline_access` scope, the authorization server will not issue a refresh token. When the access token expires, the library cannot silently refresh it, and the user will need to re-authenticate. This is especially problematic for long-lived sessions.

**Fix**: Add `options.Scope.Add("offline_access");`

## Issue 3: Manual Token Caching (`_cachedToken` field)

```csharp
// ❌ Double-caching alongside the library
private string? _cachedToken;
public async Task<string> CallApi()
{
    if (_cachedToken != null) return _cachedToken;
    var result = await _tokenManager.GetAccessTokenAsync(...);
    var token = result.GetToken();
    _cachedToken = token.AccessToken.ToString();
}
```

**Problem**: The library already caches tokens internally (using `HybridCache` in v4). Storing a token in a field creates a double-cache that won't stay in sync with the library's cache. When the library refreshes a token (because it expired or was revoked), the `_cachedToken` field still holds the old, expired token and will continue serving it. This causes 401 errors that are very difficult to debug.

**Fix**: Remove `_cachedToken` entirely. Call `GetAccessTokenAsync` on every request — the library serves from cache transparently and handles refresh automatically.

## Issue 4: Calling `.GetToken()` Without Checking `.Succeeded`

```csharp
// ❌ No error check before accessing the token
var result = await _tokenManager.GetAccessTokenAsync(...);
var token = result.GetToken(); // throws InvalidOperationException on failure
_cachedToken = token.AccessToken.ToString();
```

**Problem**: In v4, `GetAccessTokenAsync` returns a `TokenResult<T>`. Calling `.GetToken()` when `Succeeded` is `false` throws `InvalidOperationException`. The actual error (network failure, invalid credentials, etc.) is swallowed unless you check `.Succeeded` first.

**Fix**:
```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
if (!result.Succeeded)
{
    // Log and handle the error
    return;
}
var token = result.GetToken();
```

## Issue 5: `AddClientCredentialsTokenHandler` Without `AddDefaultAccessTokenResiliency()`

```csharp
// ❌ No resiliency handler
builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddClientCredentialsTokenHandler("catalog.client");
```

**Problem**: When using `AddClientCredentialsTokenHandler` directly (instead of `AddClientCredentialsHttpClient`), the built-in resiliency handler is not automatically included. Without it, if a cached token has expired at the API but not yet in the local cache, the 401 response is returned directly to the caller with no retry. `AddClientCredentialsHttpClient` includes this retry behavior automatically, but `AddClientCredentialsTokenHandler` does not.

**Fix**: Add `.AddDefaultAccessTokenResiliency()` before `.AddClientCredentialsTokenHandler(...)`:

```csharp
builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddDefaultAccessTokenResiliency()
    .AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("catalog.client"));
```

## Summary

| # | Issue | Severity |
|---|-------|----------|
| 1 | Missing `SaveTokens = true` | **Critical** — runtime crash |
| 2 | Missing `offline_access` scope | **High** — no silent token refresh |
| 3 | Manual `_cachedToken` field | **High** — stale tokens, 401 errors |
| 4 | `.GetToken()` without `.Succeeded` check | **High** — swallowed errors, unhandled exception |
| 5 | Missing `AddDefaultAccessTokenResiliency()` | **Medium** — no retry on expired-token 401 |
