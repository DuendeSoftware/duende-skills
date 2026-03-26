# Code Review

## Issues Found

### 1. Missing `SaveTokens = true`
The OIDC handler doesn't have `SaveTokens = true`. This means tokens won't be persisted in the authentication cookie, and the token management library can't access them.

### 2. Missing `offline_access` scope
Without `offline_access`, no refresh token will be issued. The access token will expire without the ability to silently renew it.

### 3. Manual token caching
The `_cachedToken` field is problematic — you're caching the token yourself alongside the library's cache. This will lead to stale tokens being used after the library refreshes them.

### 4. Missing error handling
The code calls `.GetToken()` without checking if the token retrieval succeeded. If the token request fails, this will throw an exception.

These issues should be fixed for production use.
