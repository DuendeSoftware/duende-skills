# Top 3 Client Hardening Steps for IdentityServer

## 1. Enable PKCE

Always require PKCE (Proof Key for Code Exchange) on authorization code clients. This prevents code interception attacks.

```csharp
RequirePkce = true
```

## 2. Use Exact Redirect URIs

Don't use wildcard redirect URIs. Each URI should be an exact match to prevent open redirect attacks.

## 3. Use Short-Lived Access Tokens

Keep access token lifetimes short (5-15 minutes) to minimize the window of opportunity if a token is compromised. Use refresh tokens for longer sessions.

```csharp
AccessTokenLifetime = 300 // 5 minutes
```
