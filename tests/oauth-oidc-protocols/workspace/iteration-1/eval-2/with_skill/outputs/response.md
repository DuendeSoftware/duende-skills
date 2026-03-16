# Authorization Code Flow with PKCE — Step-by-Step

## What is PKCE?

PKCE (Proof Key for Code Exchange, pronounced "pixy") is an extension to the authorization code flow defined in RFC 7636. It prevents **authorization code interception attacks** — scenarios where an attacker intercepts the authorization code during the redirect and exchanges it for tokens.

## How It Works — Step by Step

### Step 1: Client Generates PKCE Parameters

Before initiating the flow, the client generates a random `code_verifier` — a cryptographically random string (43–128 characters, URL-safe). It then computes the `code_challenge` as the **Base64URL-encoded SHA256 hash** of the `code_verifier`:

```
code_verifier  = random_string(43..128)
code_challenge = BASE64URL(SHA256(code_verifier))
```

### Step 2: Redirect to the Authorize Endpoint

The client redirects the user's browser to the authorization server's `/authorize` endpoint, including the PKCE parameters:

```
GET /authorize?
    response_type=code
    &client_id=web.app
    &redirect_uri=https://app.example.com/callback
    &scope=openid profile api1
    &state=random_state
    &nonce=random_nonce
    &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
    &code_challenge_method=S256
```

Key parameters:
- `code_challenge` — the SHA256 hash of the code_verifier
- `code_challenge_method=S256` — indicates SHA256 was used (the only recommended method)

### Step 3: User Authenticates

The user authenticates at IdentityServer (enters credentials, MFA, etc.) and optionally consents to the requested scopes.

### Step 4: Authorization Code Returned

IdentityServer redirects back to the client's `redirect_uri` with an authorization code:

```
GET /callback?
    code=SplxlOBeZQQYbYS6WxSbIA
    &state=random_state
```

The `code` is a short-lived, single-use authorization code. The `state` parameter is verified by the client to prevent CSRF.

### Step 5: Token Exchange with Code Verifier

The client exchanges the authorization code at the **token endpoint**, including the original `code_verifier`:

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https://app.example.com/callback
&client_id=web.app
&client_secret=secret
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

### Step 6: Server Verifies PKCE

The authorization server:
1. Takes the `code_verifier` from the token request
2. Computes `BASE64URL(SHA256(code_verifier))`
3. Compares it with the `code_challenge` that was sent in Step 2
4. Only issues tokens if they match

### Step 7: Tokens Returned

If everything checks out, the server returns:
```json
{
    "id_token": "eyJ...",
    "access_token": "eyJ...",
    "refresh_token": "8xLO...",
    "token_type": "Bearer",
    "expires_in": 3600
}
```

## Why PKCE Prevents Authorization Code Interception

Without PKCE, if an attacker intercepts the authorization code (e.g., through a compromised redirect, a malicious app on the device, or browser history), they can exchange it at the token endpoint for tokens — they only need the client_id (which is public).

With PKCE, the attacker **cannot produce the matching `code_verifier`** because:
- The `code_verifier` was never sent through the browser (only the hash was in the initial request)
- The `code_verifier` is only sent directly to the token endpoint over a secure backchannel
- The attacker only has the `code_challenge` (the hash), and SHA256 is a one-way function — they cannot reverse it

## Duende IdentityServer and PKCE

- **Duende IdentityServer requires PKCE by default** (`RequirePkce = true` on clients). This is a security best practice.
- **ASP.NET Core's OIDC handler sends PKCE automatically since .NET 7** — no extra configuration is needed on the client side. The handler generates the code_verifier and code_challenge transparently.

```csharp
// Duende IdentityServer client configuration — PKCE is required by default
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code, // authorization code
    RequirePkce = true, // this is the default — set explicitly for clarity
    // ...
}
```

## Flow Diagram

```
┌──────┐          ┌──────────┐          ┌──────────────┐
│Client│          │  Browser  │          │IdentityServer│
└──┬───┘          └────┬─────┘          └──────┬───────┘
   │  1. Generate PKCE │                       │
   │  code_verifier    │                       │
   │  code_challenge   │                       │
   │                   │                       │
   │  2. Redirect ───────────────────────────► │
   │     /authorize?code_challenge=...         │
   │     &code_challenge_method=S256           │
   │                   │  3. User logs in      │
   │                   │  ◄──────────────────► │
   │                   │                       │
   │  4. Redirect back ◄────────────────────── │
   │     ?code=abc123  │                       │
   │                   │                       │
   │  5. POST /token ─────────────────────────►│
   │     code=abc123&code_verifier=...         │
   │                   │                       │
   │  6. Tokens ◄──────────────────────────────│
   │     { id_token, access_token,             │
   │       refresh_token }                     │
   └───────────────────┴───────────────────────┘
```
