# Pushed Authorization Requests (PAR) and DPoP

## Pushed Authorization Requests (PAR)

PAR (RFC 9126) moves the authorization parameters from the query string to a **backchannel POST** to the authorization server's PAR endpoint (`/connect/par` in Duende IdentityServer). Instead of putting all parameters in the authorize URL, the client:

1. **POSTs** all authorization parameters (client_id, scope, redirect_uri, code_challenge, etc.) to `/connect/par`
2. Receives a `request_uri` in the response
3. Redirects the user to the authorize endpoint with just `client_id` and `request_uri`

```
Step 1: POST /connect/par
  client_id=web.app
  &scope=openid profile api1
  &redirect_uri=https://app.example.com/callback
  &code_challenge=...
  &code_challenge_method=S256

Response: { "request_uri": "urn:ietf:params:oauth:request_uri:abc123", "expires_in": 60 }

Step 2: Redirect to /authorize?client_id=web.app&request_uri=urn:ietf:params:oauth:request_uri:abc123
```

### Why PAR Improves Security

- **Prevents parameter tampering** — Authorization parameters are sent directly to the server over a secure backchannel, not through the browser's URL bar where they could be intercepted or modified
- **Eliminates URL length issues** — Complex authorization requests with many parameters no longer hit URL length limits
- **Enables authenticated requests** — The client authenticates to the PAR endpoint, proving the request came from a legitimate client

## DPoP (Demonstrating Proof-of-Possession)

DPoP (RFC 9449) **binds access tokens to a client's cryptographic key pair**. This prevents token theft and replay — even if an attacker steals an access token, they cannot use it without the corresponding private key.

### How DPoP Works

1. The client generates an asymmetric key pair
2. For every request to the token endpoint and every API call, the client creates a **DPoP proof** — a signed JWT containing the public key, the HTTP method, and the target URL
3. The token endpoint binds the issued access token to the client's public key via a **`cnf` (confirmation) claim**
4. When the API receives the token, it verifies the DPoP proof matches the token's `cnf` claim

If an attacker steals the access token, they cannot produce valid DPoP proofs because they don't have the private key. The token is useless without the matching proof.

### Why DPoP Improves Security

- **Prevents stolen token replay** — Access tokens bound to a key pair are useless without the private key
- **Complements PKCE** — PKCE protects the authorization code exchange; DPoP protects the access token itself
- **Works with bearer token infrastructure** — DPoP is an upgrade path from bearer tokens without requiring mTLS infrastructure

## FAPI 2.0

**FAPI 2.0** (Financial-grade API Security Profile) is a stringent security profile that **requires PAR and DPoP (or mTLS)** for enhanced security. It's designed for financial services and other high-security APIs. Duende IdentityServer supports FAPI 2.0 compliance from v7.3+.

FAPI 2.0 mandates:
- PAR for all authorization requests
- DPoP or mTLS for sender-constrained tokens
- Stricter redirect URI validation
- Additional protections against token leakage

## When Would You Need Them?

- **PAR** — When your authorization requests contain sensitive data, when you need to prevent parameter tampering, or when you're building a financial-grade application
- **DPoP** — When token theft is a significant risk, when you need proof-of-possession without mTLS infrastructure, or when targeting FAPI 2.0 compliance
- **Both** — When building financial services, healthcare, or other regulated applications requiring the highest security guarantees
