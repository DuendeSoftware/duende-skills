# Authorization Code Flow with PKCE

## What is PKCE?
PKCE (Proof Key for Code Exchange, RFC 7636, pronounced "pixie") binds an authorization request to the token request that redeems it. The client invents a random secret (`code_verifier`) and sends only its hash (`code_challenge`) up front. When redeeming the code, it sends the verifier. The server checks the hash matches.

## Why it's necessary
An authorization code travels through the browser (redirect URL), where it can leak via logs, referrer headers, malicious apps registered for the same custom scheme, etc. Without PKCE anyone holding the code could redeem it (public clients have no secret). With PKCE, a stolen code is useless without the verifier, which never left the client. It's now recommended for all clients, including confidential ones (OAuth 2.1), and protects against code injection.

## Step by step
1. **User clicks Login.** Client generates:
   - `code_verifier`: 43–128 chars of random URL-safe data
   - `code_challenge = BASE64URL(SHA256(code_verifier))`, `code_challenge_method=S256`
   - `state` (CSRF) and, for OIDC, `nonce`
2. **Authorization request** (browser redirect):
```
GET /connect/authorize?client_id=web
  &redirect_uri=https://app.example.com/signin-oidc
  &response_type=code
  &scope=openid profile api1
  &state=abc&nonce=xyz
  &code_challenge=E9Melhoa...&code_challenge_method=S256
```
3. **User authenticates** at the identity provider and consents.
4. **Redirect back** with `?code=SplxlOBe...&state=abc`. The client verifies `state`.
5. **Token request** (back channel, POST):
```
POST /connect/token
grant_type=authorization_code
&code=SplxlOBe...
&redirect_uri=https://app.example.com/signin-oidc
&client_id=web
&code_verifier=dBjftJeZ4CVP...
(+ client_secret for confidential clients)
```
6. **Server validates**: code valid, unused, unexpired, redirect_uri matches, and `BASE64URL(SHA256(code_verifier)) == code_challenge`.
7. **Response**: `access_token`, `id_token` (OIDC), optionally `refresh_token`. The client validates the ID token (signature, issuer, audience, expiry, nonce).

## ASP.NET Core
```csharp
builder.Services.AddAuthentication(o => { o.DefaultScheme = "Cookies"; o.DefaultChallengeScheme = "oidc"; })
    .AddCookie("Cookies")
    .AddOpenIdConnect("oidc", o =>
    {
        o.Authority = "https://identity.example.com";
        o.ClientId = "web";
        o.ClientSecret = "secret";
        o.ResponseType = "code";
        o.UsePkce = true; // default
        o.SaveTokens = true;
        o.Scope.Add("api1");
    });
```
