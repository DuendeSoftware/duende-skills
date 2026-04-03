# Authorization Code Flow with PKCE — Step by Step

## What is PKCE?

PKCE (Proof Key for Code Exchange, pronounced "pixie") is an extension to the OAuth 2.0 authorization code flow defined in RFC 7636. It prevents **authorization code interception attacks** where an attacker who intercepts the authorization code during the redirect cannot exchange it for tokens.

## The Flow Step by Step

### Step 1: Client Generates PKCE Parameters

Before initiating the flow, the client generates two values:

- **`code_verifier`**: A cryptographically random string (43–128 characters, URL-safe)
- **`code_challenge`**: The SHA256 hash of the `code_verifier`, Base64-URL-encoded

```
code_verifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
code_challenge = Base64URL(SHA256(code_verifier))
               = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
```

### Step 2: Redirect to the Authorize Endpoint

The client redirects the user's browser to the IdentityServer's authorize endpoint with these parameters:

```
GET /connect/authorize?
  response_type=code
  &client_id=web.app
  &redirect_uri=https://myapp.example.com/signin-oidc
  &scope=openid profile api1
  &state=random_state_value
  &nonce=random_nonce_value
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
```

Key parameters:
- `response_type=code` — requests an authorization code
- `code_challenge` — the SHA256 hash of the verifier
- `code_challenge_method=S256` — indicates SHA256 was used

### Step 3: User Authenticates

The user logs in at IdentityServer (username/password, MFA, external provider, etc.) and optionally consents to the requested scopes.

### Step 4: Authorization Code Callback

IdentityServer redirects the user back to the client's `redirect_uri` with an authorization code:

```
HTTP/1.1 302 Found
Location: https://myapp.example.com/signin-oidc?
  code=abc123def456
  &state=random_state_value
```

The authorization code is a short-lived, one-time-use value. It is NOT a token — it must be exchanged at the token endpoint.

### Step 5: Token Exchange with code_verifier

The client makes a **backchannel** (server-to-server) POST to the token endpoint, sending the authorization code AND the original `code_verifier`:

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=abc123def456
&redirect_uri=https://myapp.example.com/signin-oidc
&client_id=web.app
&client_secret=app-secret
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

### Step 6: Server Validates and Responds

IdentityServer:
1. Hashes the received `code_verifier` using SHA256
2. Compares it to the `code_challenge` that was stored with the authorization code
3. If they match, issues tokens

```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "refresh_token": "hdh922jfkslö...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

## Why PKCE Prevents Authorization Code Interception

Without PKCE, an attacker who intercepts the authorization code (e.g., via a malicious app registered for the same custom URI scheme, or via browser history/logs) can exchange it at the token endpoint directly.

With PKCE, the attacker has the authorization code but **cannot produce the matching `code_verifier`**. The `code_challenge` was sent in the initial redirect (which the attacker can see), but SHA256 is a one-way hash — knowing the challenge doesn't reveal the verifier. Only the legitimate client that generated the original `code_verifier` can complete the exchange.

## Duende IdentityServer and PKCE

- **Duende IdentityServer requires PKCE by default** (`RequirePkce = true` on the client configuration). This can be relaxed for legacy clients, but it's strongly recommended to keep it enabled.
- **ASP.NET Core's OIDC handler sends PKCE automatically since .NET 7**. No extra client-side configuration is needed — the middleware generates the `code_verifier` and `code_challenge` and handles the exchange.

## Flow Diagram

```
┌──────┐          ┌──────────┐          ┌──────────────┐
│Client│          │  Browser  │          │IdentityServer│
└──┬───┘          └────┬─────┘          └──────┬───────┘
   │ 1. Generate PKCE  │                       │
   │ code_verifier +   │                       │
   │ code_challenge    │                       │
   │                   │                       │
   │ 2. Redirect ────────────────────────────► │
   │    /authorize?code_challenge=...          │
   │                   │ 3. User logs in       │
   │                   │ ◄───────────────────► │
   │                   │                       │
   │ 4. Callback ◄─────────────────────────── │
   │    ?code=abc123   │                       │
   │                   │                       │
   │ 5. POST /token ──────────────────────────►│
   │    code + code_verifier                   │
   │                   │                       │
   │ 6. Tokens ◄──────────────────────────────│
   │    id_token + access_token +              │
   │    refresh_token                          │
   └───────────────────┴───────────────────────┘
```
