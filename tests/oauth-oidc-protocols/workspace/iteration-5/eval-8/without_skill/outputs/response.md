# PAR and DPoP

Both are OAuth 2.0 security extensions that make the authorization code flow more robust against certain attacks. Here's what each does and when it helps.

## Pushed Authorization Requests (PAR)

In a standard authorization code flow, the client sends all the authorization request parameters (`client_id`, `redirect_uri`, `scope`, `state`, `code_challenge`, etc.) as query-string parameters on a browser redirect to the `/authorize` endpoint. That means the parameters travel through the front channel (the user's browser), where they can potentially be seen or modified, and very large requests can run into URL length limits.

**PAR changes this.** Instead of putting everything in the redirect URL:

1. The client first makes a direct, back-channel POST to the authorization server's pushed-authorization-request endpoint, sending all the parameters in the request body.
2. The server stores them and returns a `request_uri` — a short reference handle.
3. The client then redirects the browser to `/authorize` passing just that `request_uri` (and `client_id`) instead of all the individual parameters.

Benefits:

- **Prevents parameter tampering**, because the real parameters are sent over a trusted back channel, not through the browser where they could be altered.
- **Avoids URL length problems** for large authorization requests.
- The request comes from an authenticated client call, so its integrity is assured.

## DPoP (Demonstrating Proof of Possession)

Normal access tokens are **bearer tokens** — anyone who has the token can use it. If a token is stolen, the attacker can call the API with it.

**DPoP binds the token to a key held by the client** so it's no longer a pure bearer token:

1. The client creates a public/private key pair.
2. When requesting a token and when calling the API, the client sends a signed "DPoP proof" (a small JWT signed with its private key) in a `DPoP` header.
3. The authorization server binds the issued access token to the client's public key.
4. The API verifies that the caller possesses the matching private key by validating the DPoP proof against the key the token is bound to.

Benefit: a **stolen access token can't be used on its own**, because the attacker doesn't have the client's private key and therefore can't create a valid DPoP proof. This is sometimes called a "sender-constrained" or "proof-of-possession" token.

## When would you need them?

- Use **PAR** when you need stronger assurance that authorization request parameters can't be tampered with, or when your requests are large/complex.
- Use **DPoP** when protecting against token theft/replay is important and you want tokens tied to the specific client, rather than plain bearer tokens.

Together they raise the security bar compared to a plain authorization code + PKCE flow: PKCE protects the authorization code, PAR protects the authorization request, and DPoP protects the tokens themselves. They're most relevant for high-security scenarios and public clients where the risk of interception or theft is higher.
