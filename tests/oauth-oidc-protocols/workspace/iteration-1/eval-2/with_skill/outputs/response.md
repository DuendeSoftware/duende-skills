# Authorization Code Flow with PKCE — Step by Step

## What is PKCE?

PKCE (Proof Key for Code Exchange, pronounced "pixy") is an extension to the authorization code flow that prevents **authorization code interception attacks**. It was originally designed for public clients (native apps) but is now required for all clients because it eliminates an entire class of attacks.

## The Flow Step by Step

### Step 1: Client Generates PKCE Parameters

Before starting the flow, the client generates:
- **`code_verifier`**: A cryptographically random string (43-128 characters, unreserved URI characters)
- **`code_challenge`**: The SHA256 hash of the code_verifier, base64url-encoded

```
code_verifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
code_challenge = BASE64URL(SHA256(code_verifier))
               = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
```

The client stores the `code_verifier` in session state — it will need it later.

### Step 2: Authorize Endpoint Redirect

The client redirects the user's browser to the IdentityServer authorize endpoint:

```
GET /connect/authorize?
    response_type=code
    &client_id=web.app
    &redirect_uri=https://webapp.example.com/callback
    &scope=openid profile api1
    &state=random_state_value
    &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
    &code_challenge_method=S256
    &nonce=random_nonce_value
```

Key parameters:
- `response_type=code` — Requests an authorization code
- `code_challenge` — The SHA256 hash of the code_verifier
- `code_challenge_method=S256` — Indicates SHA256 was used (not plain)
- `state` — CSRF protection (echoed back in the response)
- `nonce` — Replay protection (embedded in the ID token)

### Step 3: User Authenticates and Consents

IdentityServer presents the login page. The user enters credentials. If consent is required, the consent screen is shown.

### Step 4: Authorization Code Callback

IdentityServer redirects the browser back to the client's redirect URI with the authorization code:

```
GET /callback?
    code=SplxlOBeZQQYbYS6WxSbIA
    &state=random_state_value
```

The authorization code is a short-lived, one-time-use token. It cannot be used alone — it must be exchanged at the token endpoint with the `code_verifier`.

### Step 5: Token Exchange (Backchannel)

The client makes a backchannel POST to the token endpoint, including the **original `code_verifier`**:

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https://webapp.example.com/callback
&client_id=web.app
&client_secret=app-secret
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

### Step 6: Server Verification

IdentityServer:
1. Looks up the stored `code_challenge` associated with this authorization code
2. Computes `BASE64URL(SHA256(code_verifier))` from the received `code_verifier`
3. Compares the computed value with the stored `code_challenge`
4. If they match, the code is valid — IdentityServer returns tokens

### Step 7: Token Response

```json
{
    "id_token": "eyJhbGciOiJSUzI1NiIs...",
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "refresh_token": "CfDJ8Nb...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "openid profile api1"
}
```

## Why PKCE Prevents Code Interception

Without PKCE, an attacker who intercepts the authorization code (e.g., via a malicious browser extension, a compromised redirect, or a custom URI scheme collision on mobile) can exchange it at the token endpoint. With PKCE, the attacker also needs the `code_verifier` — which was never transmitted in the redirect and is only sent in the backchannel token request.

**Duende IdentityServer requires PKCE by default** (`RequirePkce = true` on all clients). The ASP.NET Core OIDC authentication handler automatically sends PKCE parameters since .NET 7, so no extra configuration is needed on the client side.
