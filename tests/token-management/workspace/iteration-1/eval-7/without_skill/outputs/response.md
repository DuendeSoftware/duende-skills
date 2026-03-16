# Code Review: Token Management Issues

Here are the issues I found:

## Issue 1: Missing `SaveTokens = true`

The OIDC handler options don't include `SaveTokens = true`. This means the access token and refresh token from the OIDC flow won't be persisted in the authentication cookie. The token management library needs these tokens to be stored so it can read and refresh them. Without this setting, attempts to get the user's access token will fail at runtime.

**Fix**: Add `options.SaveTokens = true;` in the OIDC handler configuration.

## Issue 2: Missing `offline_access` Scope

The scopes only include `openid` and `api1`. Without `offline_access`, the authorization server won't issue a refresh token. This means when the access token expires, the user will need to re-authenticate instead of the token being silently refreshed.

**Fix**: Add `options.Scope.Add("offline_access");`

## Issue 3: Manual Token Caching

The `_cachedToken` field in the service manually caches the token. This is problematic because:
- The cached token will become stale when it expires
- The token management library already handles caching internally
- There's no mechanism to invalidate this manual cache when a new token is obtained

**Fix**: Remove the `_cachedToken` field and call the token manager directly on each request.

## Issue 4: Missing Error Handling on Token Result

The code calls `result.GetToken()` directly without checking if the token retrieval was successful. If the token request fails, this could throw an exception or return an invalid token.

**Fix**: Check the result status before accessing the token:
```csharp
var result = await _tokenManager.GetAccessTokenAsync(...);
if (result.IsError)
{
    // Handle error
    return;
}
var token = result.GetToken();
```

## Summary

1. Add `SaveTokens = true` to OIDC options
2. Add `offline_access` scope
3. Remove manual token caching
4. Add error handling for token retrieval
