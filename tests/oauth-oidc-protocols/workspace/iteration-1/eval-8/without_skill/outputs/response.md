# PAR and DPoP

## Pushed Authorization Requests (PAR)

PAR is an OAuth 2.0 extension (RFC 9126) that changes how authorization requests are initiated. Instead of putting all parameters in the authorization URL's query string, the client first sends the parameters to a dedicated PAR endpoint via a POST request. The server returns a `request_uri` that the client then uses in the redirect to the authorize endpoint.

### Benefits
- Reduces the risk of parameter leakage through browser history or referrer headers
- Avoids URL length limits for complex authorization requests
- The authorization server can authenticate the client before processing the request

## DPoP (Demonstrating Proof-of-Possession)

DPoP (RFC 9449) is a mechanism to bind access tokens to a cryptographic key held by the client. The client generates a key pair and includes a DPoP proof (a signed JWT) with token requests and API calls. The server binds the token to the client's key.

### How It Works
1. Client generates an asymmetric key pair
2. Client creates a DPoP proof JWT signed with the private key
3. Token endpoint issues a token with a `cnf` claim binding it to the public key
4. API verifies the DPoP proof matches the token's binding

### Benefits
- Prevents token theft — stolen tokens can't be used without the private key
- Works without requiring mutual TLS infrastructure

## Comparison with Standard Auth Code + PKCE

Standard authorization code + PKCE already provides good security:
- PKCE prevents code interception
- The authorization code is short-lived

PAR and DPoP add additional layers:
- PAR prevents tampering with authorization parameters
- DPoP prevents access token replay even if the token is stolen

These are particularly important in high-security scenarios like financial APIs.
