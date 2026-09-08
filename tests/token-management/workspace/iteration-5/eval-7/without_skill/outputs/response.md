# Code Review

A few problems stand out in this setup.

## 1. `SaveTokens` is not enabled

The OpenID Connect handler doesn't set `SaveTokens = true`. Without it, the access and refresh tokens aren't stored in the authentication session, so `AddOpenIdConnectAccessTokenManagement()` has nothing to read or refresh and user-token calls will fail at runtime.

```csharp
options.SaveTokens = true;
```

## 2. Missing `offline_access` scope

Only `openid` and `api1` are requested. Without `offline_access`, the identity provider won't issue a refresh token, so once the access token expires the user has to log in again instead of the token being refreshed silently.

```csharp
options.Scope.Add("offline_access");
```

## 3. Manual token caching in a field

```csharp
private string? _cachedToken;
if (_cachedToken != null) return _cachedToken;
```

This is a real bug. The token management library already caches tokens and knows when they expire. Caching the string yourself in a field means it's never refreshed — after expiry you keep handing out a dead token and calls start returning 401. Remove `_cachedToken` and call the token manager (or use a token-handler-backed `HttpClient`) every time; it will serve a valid token from its own cache.

## 4. A registered client-credentials handler but no client defined

`AddClientCredentialsTokenHandler("catalog.client")` references a client named `catalog.client`, but no such client credentials client is registered anywhere (only the OIDC web client is configured). That handler will fail to resolve a token. You need to register the client credentials client (token endpoint, client id/secret, scope) before referencing it.

## 5. Consider token-request error handling

The service calls `result.GetToken()` right after requesting the token. Make sure failures are handled rather than assuming a token always comes back, otherwise a token-server outage becomes an unhandled exception in your request path.

## Recommendations

- Add `SaveTokens = true` and `offline_access`.
- Wire up refresh-token revocation on sign-out so tokens can't be reused after logout.
- Delete the `_cachedToken` field and rely on the library's cache.
- Register the `catalog.client` client credentials client that the handler references.
