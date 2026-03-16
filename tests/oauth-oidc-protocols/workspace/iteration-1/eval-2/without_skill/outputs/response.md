# Authorization Code Flow with PKCE

## Overview

The authorization code flow with PKCE (Proof Key for Code Exchange) is the recommended OAuth 2.0 flow for web applications, mobile apps, and single-page applications. It's an extension of the standard authorization code flow that adds protection against authorization code interception attacks.

## What is PKCE?

PKCE (pronounced "pixy", defined in RFC 7636) adds a proof mechanism to the authorization code exchange. The client creates a secret (the code verifier) and sends a hash of it in the initial authorization request. When exchanging the code for tokens, the client sends the original secret, and the server verifies it matches the hash.

## Step-by-Step Flow

### 1. Generate Code Verifier and Challenge

The client generates a random `code_verifier` (a cryptographic random string) and computes its SHA256 hash as the `code_challenge`:

```
code_verifier = random(43..128 characters)
code_challenge = BASE64URL(SHA256(code_verifier))
```

### 2. Redirect to Authorization Endpoint

The client redirects the user to the authorization server with the code_challenge:

```
GET /authorize?
    response_type=code
    &client_id=web.app
    &redirect_uri=https://app.example.com/callback
    &scope=openid profile
    &state=xyz
    &code_challenge=<hashed_verifier>
    &code_challenge_method=S256
```

The `code_challenge` and `code_challenge_method=S256` parameters tell the server this is a PKCE flow using SHA256.

### 3. User Authenticates

The user logs in at the authorization server and grants consent if needed.

### 4. Authorization Code Callback

The server redirects back to the client with an authorization code:

```
GET /callback?code=SplxlOBeZQQYbYS6WxSbIA&state=xyz
```

### 5. Token Exchange with Code Verifier

The client sends the authorization code along with the original `code_verifier` to the token endpoint:

```
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https://app.example.com/callback
&client_id=web.app
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

### 6. Server Verifies and Returns Tokens

The server hashes the `code_verifier`, compares it to the stored `code_challenge`, and if they match, returns the tokens.

## Why PKCE is Necessary

PKCE prevents authorization code interception attacks. Without PKCE, an attacker who intercepts the authorization code (e.g., via a malicious app on the same device) could exchange it for tokens. With PKCE, the attacker cannot produce the matching code_verifier because they never had access to it — only the SHA256 hash was transmitted via the browser.

## ASP.NET Core Integration

In ASP.NET Core, when using the OpenID Connect handler, PKCE is handled automatically. You don't need to manually generate the verifier and challenge.

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.SaveTokens = true;
});
```
