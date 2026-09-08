# PAR and DPoP — What They Are and Why They Help

Both PAR and DPoP are OAuth security extensions that harden the authorization code + PKCE flow against distinct attacks. PKCE protects the *code*; PAR protects the *authorization request*; DPoP protects the *tokens*.

## Pushed Authorization Requests (PAR) — RFC 9126

In a normal authorization code flow, all the authorization parameters (`client_id`, `scope`, `redirect_uri`, `state`, `code_challenge`, etc.) are put in the **query string** of a front-channel browser redirect to `/authorize`. That query string travels through the user's browser, so it can be observed and tampered with, and long requests can hit URL-length limits.

**PAR moves those parameters off the front channel.** The flow becomes:

1. The client makes a **backchannel POST** (server-to-server, authenticated) to the **`/connect/par`** endpoint, sending all the authorization parameters in the request body.
2. IdentityServer validates and stores them, and returns a **`request_uri`** — an opaque handle.
3. The client then redirects the browser to the authorize endpoint referencing only that handle:

```
GET /connect/authorize?client_id=web.app&request_uri=urn:ietf:params:oauth:request_uri:abc123
```

Because the real parameters were pushed over an authenticated backchannel and only an opaque `request_uri` appears in the browser URL:

- **Parameter tampering is prevented** — the browser never carries the mutable parameters, so a user/attacker can't alter `scope`, `redirect_uri`, etc. in transit.
- **URL length issues disappear** — big requests (many scopes, rich authorization details, JAR objects) no longer overflow query-string limits.
- The request is integrity-protected and originates from the authenticated client.

## DPoP (Demonstrating Proof-of-Possession) — RFC 9449

Standard bearer access tokens have a fundamental weakness: **whoever holds the token can use it.** If a bearer token is stolen (leaked logs, MITM, malicious dependency), the attacker can replay it against the API.

**DPoP makes tokens sender-constrained** by binding them to a cryptographic key the client holds:

1. The client generates a **public/private key pair**.
2. On each token request (and each API call), the client creates a **DPoP proof** — a short JWT signed with its private key, containing the public key and a hash of the request.
3. IdentityServer binds the issued access token to that public key by embedding a **`cnf` (confirmation) claim** (a thumbprint of the key) in the token.
4. When the client calls the API, it sends both the access token and a fresh DPoP proof. The API checks that the proof is signed by the key whose thumbprint is in the token's `cnf` claim.

The result: a **stolen access token is useless without the corresponding private key**. An attacker who exfiltrates the token cannot produce a valid DPoP proof, so the API rejects the request. This defeats token theft and replay in a way plain bearer tokens cannot.

## When would you need them?

- **PAR:** when you want request integrity (no front-channel tampering), are sending large/complex authorization requests, or must meet a high-security profile.
- **DPoP:** when bearer-token theft is a serious concern and you want tokens that are cryptographically bound to the legitimate client (an alternative to mTLS-bound tokens without needing client certificates).

## FAPI 2.0

These aren't just optional hardening — they're mandated by high-assurance profiles. **FAPI 2.0** (Financial-grade API, the profile used in open banking and other high-value APIs) **requires PAR, and requires sender-constrained tokens via DPoP *or* mTLS**, along with stricter validation across the board. If you need FAPI 2.0 compliance, PAR + DPoP (or mTLS) are non-negotiable. Duende IdentityServer supports both PAR and DPoP and offers FAPI 2.0 compliance (from v7.3+).

## Summary

| Extension | Protects | Mechanism | Attack prevented |
|-----------|----------|-----------|------------------|
| PKCE | the code | verifier/challenge | code interception |
| PAR | the request | backchannel push → `request_uri` | parameter tampering, URL limits |
| DPoP | the tokens | key-bound `cnf` claim + proof JWT | token theft / replay |
