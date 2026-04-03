# Pushed Authorization Requests (PAR) and DPoP

## Pushed Authorization Requests (PAR)

### What Is PAR?

PAR (RFC 9126) moves the authorization parameters from the browser's query string to a **backchannel POST** request. Instead of putting all parameters (client_id, scope, redirect_uri, code_challenge, etc.) in the authorize URL, the client first POSTs them to a dedicated PAR endpoint, receives a `request_uri`, and then redirects the user with only that `request_uri`.

### How PAR Works

```
1. Client POSTs all authorization parameters to /connect/par
   → IdentityServer validates them and returns a request_uri

2. Client redirects user to:
   /connect/authorize?request_uri=urn:ietf:params:oauth:request_uri:abc123&client_id=web.app
```

Step by step:

```
┌──────┐                              ┌──────────────┐
│Client│                              │IdentityServer│
└──┬───┘                              └──────┬───────┘
   │  1. POST /connect/par                   │
   │     client_id, scope, redirect_uri,     │
   │     code_challenge, ...                 │
   │  ──────────────────────────────────►    │
   │                                         │
   │  { "request_uri": "urn:...abc123",      │
   │    "expires_in": 60 }                   │
   │  ◄──────────────────────────────────    │
   │                                         │
   │  2. Redirect browser to:                │
   │  /authorize?request_uri=urn:...abc123   │
   │  ──────────────────────────────────►    │
   └─────────────────────────────────────────┘
```

### Why PAR Improves Security

- **Prevents parameter tampering** — Authorization parameters are sent server-to-server over TLS, not through the browser where they could be intercepted or modified
- **Prevents URL length issues** — Complex authorization requests with many parameters can exceed browser URL length limits; PAR moves them out of the URL
- **Confidential parameter handling** — Sensitive parameters never appear in browser history, referrer headers, or server access logs
- **Server-side validation before redirect** — IdentityServer validates all parameters upfront and rejects invalid requests before the user is redirected

## DPoP (Demonstrating Proof-of-Possession)

### What Is DPoP?

DPoP (RFC 9449) is a mechanism that **binds access tokens to a client's cryptographic key pair**, preventing stolen tokens from being used by attackers. Unlike bearer tokens (which anyone can use if they obtain them), DPoP tokens can only be used by the holder of the private key.

### How DPoP Works

```
1. Client generates an asymmetric key pair (e.g., ES256)
2. Client creates a DPoP proof — a signed JWT containing:
   - The public key (via jwk header)
   - The HTTP method and URL of the request
   - A unique jti and timestamp
3. Client sends the DPoP proof in the "DPoP" header along with the token request
4. IdentityServer issues a DPoP-bound access token with a "cnf" (confirmation) claim
   containing the thumbprint of the client's public key
5. When the client calls an API, it sends:
   - The access token in the Authorization header (as "DPoP <token>")
   - A fresh DPoP proof in the DPoP header
6. The API verifies that:
   - The DPoP proof is signed by the key matching the token's cnf claim
   - The proof covers the correct HTTP method and URL
```

### Why DPoP Improves Security

- **Prevents token theft/replay** — Even if an attacker intercepts the access token, they cannot use it without the client's private key to generate valid DPoP proofs
- **Proof is bound to the request** — Each DPoP proof covers a specific HTTP method and URL, preventing replay attacks across different endpoints
- **Sender-constrained tokens** — The `cnf` claim in the access token cryptographically binds it to the client's key, making it a proof-of-possession token rather than a bearer token

## How They Compare to Standard Auth Code + PKCE

| Feature | Auth Code + PKCE | + PAR | + DPoP |
|---------|-----------------|-------|--------|
| Code interception protection | ✅ PKCE | ✅ PKCE | ✅ PKCE |
| Parameter tampering protection | ❌ Params in URL | ✅ Backchannel | ✅ Backchannel (with PAR) |
| Token theft protection | ❌ Bearer tokens | ❌ Bearer tokens | ✅ Sender-constrained |
| Token replay protection | ❌ | ❌ | ✅ Per-request proof |

## FAPI 2.0

**FAPI 2.0** (Financial-grade API Security Profile 2.0) is an OpenID Foundation profile that mandates enhanced security for high-value API scenarios (banking, finance, healthcare). FAPI 2.0 **requires**:

- **PAR** — All authorization requests must use Pushed Authorization Requests
- **DPoP or mTLS** — Tokens must be sender-constrained via either DPoP or mutual TLS client certificate binding
- **PKCE** — Required for all authorization code flows
- Stricter redirect URI validation, shorter token lifetimes, and additional security measures

Duende IdentityServer supports FAPI 2.0 compliance from v7.3+.

## When Would You Need These?

- **PAR** — When you need to prevent parameter tampering in the authorize request, handle complex authorization parameters that exceed URL limits, or comply with FAPI 2.0
- **DPoP** — When you need to prevent token theft and replay (e.g., financial services, healthcare, high-value APIs), or when bearer tokens are insufficient for your threat model
- **Both (FAPI 2.0)** — When building financial-grade APIs, PSD2-compliant payment services, or any application requiring the highest security assurance
