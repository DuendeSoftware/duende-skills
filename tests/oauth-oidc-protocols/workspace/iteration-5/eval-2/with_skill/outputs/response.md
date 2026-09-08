# Authorization Code Flow with PKCE — Step by Step

## What PKCE is and why it's necessary

**PKCE** (Proof Key for Code Exchange, RFC 7636, pronounced "pixy") is a security extension to the OAuth 2.0 authorization code flow. It solves the **authorization code interception** problem.

In the plain authorization code flow, the authorization server hands the client an authorization `code` via a browser redirect. If an attacker can intercept that redirect (a malicious app registered on the same custom URI scheme on a mobile device, a compromised network hop, browser history, referer leakage), they could replay the code at the token endpoint and steal tokens.

PKCE closes this gap by requiring the client to prove, at the token exchange, that it is the same party that started the flow — using a secret it never put on the wire in plaintext.

## The building blocks

- **`code_verifier`** — a high-entropy random string the client generates and keeps in memory (never sent in the authorize request).
- **`code_challenge`** — the SHA256 hash of the `code_verifier`, base64url-encoded: `code_challenge = BASE64URL(SHA256(code_verifier))`.
- **`code_challenge_method=S256`** — tells the server the challenge is a SHA256 hash (the only method you should use; `plain` exists but is discouraged).

## Step-by-step at the protocol level

**Step 1 — Generate PKCE values.**
The client generates a random `code_verifier`, then computes `code_challenge = BASE64URL(SHA256(code_verifier))`. It stashes the `code_verifier` locally (tied to the session/state).

**Step 2 — Authorize redirect.**
The client redirects the browser to the authorize endpoint:

```
GET /connect/authorize?
    client_id=web.app
    &redirect_uri=https://web.app/signin-oidc
    &response_type=code
    &scope=openid profile api1
    &state=xyz
    &nonce=n-0S6_WzA2Mj
    &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
    &code_challenge_method=S256
```

Note the `code_challenge` and `code_challenge_method=S256` are on the request; the verifier is **not**.

**Step 3 — User authenticates.**
At IdentityServer, the user logs in (and consents if required). The server stores the `code_challenge` associated with the authorization code it is about to issue.

**Step 4 — Callback with the authorization code.**
IdentityServer redirects back to the client's `redirect_uri`:

```
GET /signin-oidc?code=abc123&state=xyz
```

**Step 5 — Token exchange with the code_verifier.**
The client POSTs to the token endpoint, now presenting the **original `code_verifier`**:

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=abc123
&redirect_uri=https://web.app/signin-oidc
&client_id=web.app
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

**Step 6 — Server verifies the proof.**
IdentityServer recomputes `SHA256(code_verifier)`, base64url-encodes it, and compares it to the `code_challenge` it stored in step 3. If they match, the code is genuine and the requesting party owns the verifier.

**Step 7 — Tokens returned.**
The server responds with an `id_token` (proves the user's identity, consumed by your web app), an `access_token` (authorizes API calls, consumed by the API), and a `refresh_token` if `offline_access` was requested.

## Why this defeats code interception

An attacker who intercepts the authorization `code` in step 4 still cannot exchange it: the token endpoint demands the matching `code_verifier`, and only its SHA256 hash (the challenge) ever appeared on the wire. SHA256 is one-way, so the attacker cannot derive the verifier from the challenge. Without the verifier, step 6 fails and the stolen code is useless.

## Duende / ASP.NET Core specifics

- **Duende IdentityServer requires PKCE by default** — interactive clients have `RequirePkce = true`, so an authorization-code request without a `code_challenge` is rejected.
- **ASP.NET Core's OpenID Connect handler sends PKCE automatically since .NET 7.** If you're on .NET 7 or later you get PKCE with no extra client configuration; the handler generates the verifier/challenge, keeps the verifier in the correlation cookie, and sends it at the token exchange for you. (On .NET 6 you had to set `options.UsePkce = true`.)

So for a modern ASP.NET Core web app using `AddOpenIdConnect`, PKCE is on by default on both ends — you generally don't write any of the above by hand, but understanding the protocol helps when debugging.
