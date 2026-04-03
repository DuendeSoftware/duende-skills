# Code Review: Token Management Issues

Here are the problems I can identify in the provided code:

## Issue 1: Missing `SaveTokens = true`

The OpenIdConnect handler doesn't set `SaveTokens = true`. This is needed so tokens are stored in the authentication properties and can be retrieved later for API calls.

**Fix**: Add `options.SaveTokens = true;` to the OIDC options.

## Issue 2: Missing `offline_access` Scope

The OIDC configuration only requests `openid` and `api1` scopes. Without `offline_access`, the authorization server won't issue a refresh token, meaning when the access token expires, the user will need to re-authenticate.

**Fix**: Add `options.Scope.Add("offline_access");`.

## Issue 3: Manual Token Caching

The service maintains its own `_cachedToken` field. This is problematic because:
- The cached token will never be updated when it expires
- It doesn't account for different users or sessions
- It may serve stale tokens after the library has refreshed them

**Fix**: Always call `GetAccessTokenAsync` and let the library handle caching.

## Issue 4: Missing Error Handling on Token Result

The code calls `result.GetToken()` without checking if the token request was successful first. If the token request fails, this could throw an exception or return invalid data.

**Fix**: Check the result status before accessing the token:
```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
if (result.Succeeded)
{
    var token = result.GetToken();
    // use token
}
```

## Summary

| # | Issue | Severity |
|---|-------|----------|
| 1 | Missing `SaveTokens = true` | Critical |
| 2 | Missing `offline_access` scope | High |
| 3 | Manual token caching | High |
| 4 | Missing error handling | Medium |
