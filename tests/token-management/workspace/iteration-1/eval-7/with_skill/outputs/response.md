# Code Review: Token Management Issues

Here are all the problems in your code:

## Issue 1: Missing `SaveTokens = true`

```csharp
.AddOpenIdConnect("oidc", options =>
{
    // ❌ SaveTokens not set — defaults to false
    // The token management library cannot read or refresh tokens without this
});
```

**Fix:** Add `options.SaveTokens = true;`. This is the single most common misconfiguration with user token management. Without it, the OIDC handler discards tokens after authentication, and `AddOpenIdConnectAccessTokenManagement()` throws `InvalidOperationException` at runtime.

## Issue 2: Missing `offline_access` Scope

```csharp
options.Scope.Add("openid");
options.Scope.Add("api1");
// ❌ No offline_access — no refresh token will be issued
```

**Fix:** Add `options.Scope.Add("offline_access");`. Without a refresh token, the access token cannot be silently renewed — the user must re-authenticate when it expires.

## Issue 3: No Refresh Token Revocation on Sign-Out

The code doesn't revoke the refresh token when the user signs out. This means the refresh token remains valid at the authorization server after logout.

**Fix:**
```csharp
.AddCookie("cookie", options =>
{
    options.Events.OnSigningOut = async e =>
    {
        await e.HttpContext.RevokeRefreshTokenAsync();
    };
});
```

## Issue 4: Manual Token Caching (`_cachedToken`)

```csharp
private string? _cachedToken;
public async Task<string> CallApi()
{
    if (_cachedToken != null) return _cachedToken;
    // ❌ Double-caching — your cache won't stay in sync with the library's cache
```

**Fix:** Remove the `_cachedToken` field entirely. Call `GetAccessTokenAsync` on every request — the library serves from its HybridCache transparently. Your manual cache never invalidates when the library refreshes the token, so you'll end up serving expired tokens.

## Issue 5: Calling `.GetToken()` Without Checking `.Succeeded`

```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
var token = result.GetToken();  // ❌ throws InvalidOperationException if Succeeded == false
```

**Fix:**
```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
if (!result.Succeeded)
{
    // log and handle the failure
    return;
}
var token = result.GetToken();
```

## Issue 6: Missing Resiliency Handler

```csharp
.AddClientCredentialsTokenHandler("catalog.client");
// ❌ No resiliency handler — 401 from expired tokens won't be retried
```

**Fix:** Add `AddDefaultAccessTokenResiliency()` before the token handler:
```csharp
.AddDefaultAccessTokenResiliency()
.AddClientCredentialsTokenHandler("catalog.client");
```

`AddClientCredentialsHttpClient` includes this automatically, but when using `AddClientCredentialsTokenHandler` directly on an `AddHttpClient` registration, you must add it explicitly.
