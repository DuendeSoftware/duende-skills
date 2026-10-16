# Authorization Code Flow with PKCE

**Roles:** User (resource owner), your web app (client / relying party), IdentityServer (authorization server / OpenID provider), API (resource server).

## What is PKCE and why?
PKCE (RFC 7636) ties the authorization request to the token request. The client creates a random `code_verifier`, sends only its SHA-256 hash (`code_challenge`) on the front channel, and reveals the verifier on the back channel when redeeming the code. The authorization code passes through the browser, so it can be intercepted or injected; without the verifier it's worthless. It's required by default in Duende IdentityServer (`RequirePkce = true`) and is recommended for every interactive client, confidential ones included.

## Step by step
1. **Client generates PKCE values**: `code_verifier` (random, 43–128 chars), `code_challenge = BASE64URL(SHA256(verifier))`, plus `state` and `nonce`.
2. **Redirect to authorize endpoint**
```
GET /connect/authorize?client_id=web.app
  &redirect_uri=https://app.example.com/signin-oidc
  &response_type=code
  &scope=openid profile api1 offline_access
  &state=af0ifjsldkj&nonce=n-0S6_WzA2Mj
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
```
3. **User authenticates** at IdentityServer (and consents if required).
4. **Redirect back**: `https://app.example.com/signin-oidc?code=abc123&state=af0ifjsldkj`. Client checks `state`.
5. **Token request** (back channel):
```
POST /connect/token
grant_type=authorization_code&code=abc123
&redirect_uri=https://app.example.com/signin-oidc
&client_id=web.app&client_secret=...
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```
6. **IdentityServer verifies**: code valid/unused, redirect URI matches, and SHA256(verifier) equals the stored challenge.
7. **Response**: ID token (always a JWT, proves who the user is), access token (JWT or reference, for the API), refresh token if `offline_access` was granted.
8. **Client validates the ID token**: `iss`, `aud` (= client ID), `exp`, signature (keys from the discovery doc's `jwks_uri`), and `nonce`; `at_hash` binds it to the access token.

```
Client            Browser           IdentityServer
 1 gen verifier/challenge
 2 redirect ───────────────────────► /authorize?code_challenge
                   3 login ◄────────►
 4 ◄──────── redirect ?code=abc123
 5 POST /token code + code_verifier ─►
 6 ◄──── id_token, access_token, refresh_token
```

## ASP.NET Core
```csharp
builder.Services.AddAuthentication(o => { o.DefaultScheme = "Cookies"; o.DefaultChallengeScheme = "oidc"; })
    .AddCookie("Cookies")
    .AddOpenIdConnect("oidc", o =>
    {
        o.Authority = "https://identity.example.com";
        o.ClientId = "web.app";
        o.ClientSecret = "secret";
        o.ResponseType = "code";   // PKCE is sent automatically since .NET 7
        o.SaveTokens = true;
        o.Scope.Add("api1"); o.Scope.Add("offline_access");
    });
```
Remember: use the ID token (via `User`) to know who the user is; use the access token only to call APIs, and never parse it in the client.
