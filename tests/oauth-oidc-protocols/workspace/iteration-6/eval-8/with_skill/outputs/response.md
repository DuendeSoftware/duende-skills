# PAR and DPoP

Authorization code + PKCE protects the *code exchange*. It doesn't protect request parameters in the browser, nor tokens after issuance, which are plain bearer tokens. PAR and DPoP fill those gaps.

## Pushed Authorization Requests (PAR, RFC 9126)
```
1. Client POSTs all authorize parameters (authenticated) to /connect/par → request_uri
2. Browser is redirected to /authorize?client_id=...&request_uri=urn:...
```
Benefits: parameters can't be tampered with or leaked via the URL/browser, no URL length limits, the client is authenticated before the user flow starts, bad requests are rejected early, and large payloads (RAR) fit.

## DPoP (RFC 9449)
```
1. Client generates a key pair
2. Creates a DPoP proof (signed JWT incl. public key, HTTP method, URL, ath)
3. Sends it in the DPoP header with the token request
4. IdentityServer binds the token to the key via the cnf claim
5. API verifies the proof matches the token's cnf on each call
```
A stolen access or refresh token is useless without the private key, defeating theft and replay.

## When do you need them?
- Regulated/high-value environments: **FAPI 2.0** requires PAR plus DPoP or mTLS (supported in Duende IdentityServer v7.3+).
- Sensitive operations (payments, healthcare), rich authorization requests.
- Public clients where tokens might leak (SPAs/mobile).
- For typical apps, code+PKCE (with BFF for SPAs) and short-lived tokens suffice. See `identity-security-hardening`.

## Comparison
| | Code + PKCE | + PAR | + DPoP |
|---|---|---|---|
| Code interception/injection | ✅ | ✅ | ✅ |
| Authorize params tamper-proof/confidential | ❌ | ✅ | – |
| Client authenticated before login | ❌ | ✅ | – |
| Stolen access token reusable | ✅ (bearer) | ✅ | ❌ (key-bound) |

## Duende config sketch
```csharp
builder.Services.AddIdentityServer(o => { /* PAR endpoint is enabled by default in recent versions */ });
new Client
{
    ClientId = "web", AllowedGrantTypes = GrantTypes.Code,
    RequirePushedAuthorization = true,
    RequireDPoP = true,
    ...
}
```
Client side: the ASP.NET Core OIDC handler supports PAR (`PushedAuthorizationBehavior`), and `Duende.AccessTokenManagement` supports DPoP; APIs validate DPoP-bound tokens with the DPoP-aware JwtBearer extension.
