# Pushed Authorization Requests (PAR) and DPoP

## Pushed Authorization Requests (PAR)

### What It Is

PAR (RFC 9126) moves the authorization parameters from the **browser query string** to a **backchannel POST** between the client and IdentityServer. Instead of stuffing all parameters into the authorize URL, the client first POSTs them to the PAR endpoint and receives a `request_uri` in return.

### How It Works

```
Step 1: Client → IdentityServer (backchannel)
POST /connect/par
Content-Type: application/x-www-form-urlencoded

client_id=web.app
&client_secret=secret
&response_type=code
&scope=openid profile api1
&redirect_uri=https://webapp.example.com/callback
&code_challenge=xxx
&code_challenge_method=S256

Response:
{
    "request_uri": "urn:ietf:params:oauth:request_uri:abc123",
    "expires_in": 60
}

Step 2: Client → Browser redirect
GET /connect/authorize?
    client_id=web.app
    &request_uri=urn:ietf:params:oauth:request_uri:abc123
```

### Security Benefits

1. **Prevents parameter tampering** — Authorization parameters are sent directly to the server via a secure backchannel. An attacker cannot modify parameters in the browser URL.
2. **Eliminates URL length issues** — Complex authorization requests with many parameters or JWT request objects can exceed URL length limits. PAR avoids this by sending parameters in a POST body.
3. **Server-side parameter validation** — The server can validate all parameters before the user is redirected, returning errors immediately rather than after the user interacts.
4. **Reduces information leakage** — Parameters are not exposed in browser history, referrer headers, or server access logs.

## DPoP (Demonstrating Proof-of-Possession)

### What It Is

DPoP (RFC 9449) **binds access tokens to a client's cryptographic key pair**, preventing stolen tokens from being used by attackers. Standard bearer tokens can be used by anyone who possesses them. DPoP tokens are only usable by the client that holds the private key.

### How It Works

```
Step 1: Client generates an asymmetric key pair (once)

Step 2: Token Request
- Client creates a DPoP proof JWT, signed with the private key
- The proof contains the public key (jwk header), the HTTP method, and the target URL
- Client sends the proof in the "DPoP" HTTP header alongside the token request

POST /connect/token
DPoP: eyJ...  (DPoP proof JWT)

grant_type=authorization_code
&code=xxx
&code_verifier=yyy
&client_id=web.app

Step 3: IdentityServer Response
- IdentityServer validates the DPoP proof
- Issues an access token with a "cnf" (confirmation) claim containing the hash of the client's public key
- Token type is "DPoP" instead of "Bearer"

{
    "access_token": "eyJ...cnf:{jkt: 'hash-of-public-key'}...",
    "token_type": "DPoP"
}

Step 4: API Call
- Client creates a new DPoP proof for the API request
- Sends both the access token and the proof

GET /api/resource
Authorization: DPoP eyJ...
DPoP: eyJ... (new proof for this specific request)

Step 5: API Validation
- API verifies the DPoP proof is signed by the key matching the token's "cnf" claim
- If they don't match, the token is rejected
```

### Security Benefits

1. **Prevents token theft/replay** — A stolen DPoP-bound access token is useless without the private key. An attacker would need both the token AND the key.
2. **Request binding** — Each DPoP proof is bound to a specific HTTP method and URL, preventing replay across different endpoints.
3. **Sender-constrained tokens** — Unlike bearer tokens which work for anyone, DPoP tokens only work for the holder of the private key.

## FAPI 2.0

The **Financial-grade API (FAPI) 2.0** security profile requires both PAR and proof-of-possession (DPoP or mTLS) for enhanced security. FAPI 2.0 is designed for high-security scenarios like financial services, healthcare, and government APIs.

Duende IdentityServer supports FAPI 2.0 compliance from v7.3+. Clients can be configured with:

```csharp
new Client
{
    RequirePushedAuthorization = true,  // PAR required
    RequireDPoP = true                  // DPoP required
}
```

## Standard Auth Code + PKCE vs PAR + DPoP

| Threat | Auth Code + PKCE | + PAR | + DPoP |
|--------|-----------------|-------|--------|
| Code interception | ✅ Protected (PKCE) | ✅ Protected | ✅ Protected |
| Parameter tampering | ❌ Possible in URL | ✅ Protected | ✅ Protected |
| Token theft/replay | ❌ Bearer tokens reusable | ❌ Bearer tokens reusable | ✅ Protected |
| URL length limits | ❌ Possible | ✅ Eliminated | ✅ Eliminated |
