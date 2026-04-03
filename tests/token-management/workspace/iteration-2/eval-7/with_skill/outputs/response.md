# Code Review: Token Management Issues

Here are all the problems in the provided code:

## Issue 1: Missing `SaveTokens = true` on the OIDC Handler

```csharp
// ❌ Current — SaveTokens is not set (defaults to false)
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://sts.example.com";
    // ...
});
```

**Problem**: `SaveTokens = true` is **required** for user token management. Without it, the library cannot read or refresh the user's access token. The OIDC handler must persist tokens into the authentication session. This is the most common misconfiguration and will cause `InvalidOperationException` at runtime.

**Fix**: Add `options.SaveTokens = true;` to the OIDC handler options.

## Issue 2: Missing `offline_access` Scope

```csharp
// ❌ Current
options.Scope.Add("openid");
options.Scope.Add("api1");
// offline_access is missing
```

**Problem**: Without the `offline_access` scope, no refresh token will be issued by the authorization server. When the access token expires, the user must re-authenticate interactively — the library cannot silently refresh the token.

**Fix**: Add `options.Scope.Add("offline_access");`.

## Issue 3: No Refresh Token Revocation on Sign-Out

```csharp
// ❌ Current — no OnSigningOut handler on the cookie
.AddCookie("cookie")
```

**Problem**: The refresh token remains valid at the authorization server after the user signs out. This means the token could potentially be reused if compromised.

**Fix**: Add the revocation handler:
```csharp
.AddCookie("cookie", options =>
{
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync();
    };
})
```

## Issue 4: Manual Token Caching (`_cachedToken`)

```csharp
// ❌ Current — double-caching
private string? _cachedToken;
public async Task<string> CallApi()
{
    if (_cachedToken != null) return _cachedToken;
    var result = await _tokenManager.GetAccessTokenAsync(...);
    var token = result.GetToken();
    _cachedToken = token.AccessToken.ToString();
}
```

**Problem**: This is incorrect double-caching. The library already manages its own token cache (via `HybridCache` in v4). The `_cachedToken` field will never be invalidated when the library refreshes the token, so it will serve stale/expired tokens. Never store tokens in instance fields, static variables, or application-managed caches.

**Fix**: Call `GetAccessTokenAsync` on every request and let the library serve from its cache transparently.

## Issue 5: Calling `.GetToken()` Without Checking `.Succeeded`

```csharp
// ❌ Current
var result = await _tokenManager.GetAccessTokenAsync(...);
var token = result.GetToken(); // throws if Succeeded == false
```

**Problem**: `.GetToken()` throws `InvalidOperationException` when the token request fails (i.e., when `Succeeded` is `false`). The actual error is swallowed unless you inspect `Succeeded` first.

**Fix**:
```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
if (!result.Succeeded)
{
    // Log and handle error
    return;
}
var token = result.GetToken();
```

## Issue 6: Missing `AddDefaultAccessTokenResiliency()` Before `AddClientCredentialsTokenHandler`

```csharp
// ❌ Current
builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddClientCredentialsTokenHandler("catalog.client");
```

**Problem**: When using `AddClientCredentialsTokenHandler` directly (not `AddClientCredentialsHttpClient`), the built-in resiliency handler is **not** included. This means a `401 Unauthorized` response from an expired token won't trigger a retry with a fresh token. `AddClientCredentialsHttpClient` adds this automatically, but `AddClientCredentialsTokenHandler` does not.

**Fix**:
```csharp
builder.Services.AddHttpClient<ApiClient>(c => c.BaseAddress = new Uri("https://api.example.com"))
    .AddDefaultAccessTokenResiliency()
    .AddClientCredentialsTokenHandler("catalog.client");
```

## Summary

| # | Issue | Severity |
|---|-------|----------|
| 1 | Missing `SaveTokens = true` | Critical — runtime exception |
| 2 | Missing `offline_access` scope | High — no token refresh |
| 3 | No refresh token revocation on sign-out | Medium — security risk |
| 4 | Manual `_cachedToken` double-caching | High — stale tokens |
| 5 | `.GetToken()` without `.Succeeded` check | High — swallowed errors |
| 6 | Missing `AddDefaultAccessTokenResiliency()` | Medium — no 401 retry |
