# PAR and DPoP

## Pushed Authorization Requests (PAR)

PAR is a mechanism where instead of putting all OAuth parameters in the authorize URL query string, you POST them to a special endpoint first and get back a reference (`request_uri`). Then you redirect the user to the authorize endpoint with just that reference.

### How it works:

1. Client POSTs authorization parameters (client_id, scope, redirect_uri, etc.) to the PAR endpoint
2. Server validates the parameters and returns a `request_uri` and expiration
3. Client redirects the user to the authorize endpoint with `?request_uri=<value>&client_id=<value>`

### Benefits:
- Parameters aren't exposed in the browser URL bar or history
- No URL length limitations
- Server validates parameters before involving the user

## DPoP (Demonstrating Proof-of-Possession)

DPoP is a mechanism that binds tokens to a specific client by requiring the client to prove possession of a private key.

### How it works:

1. Client generates a public/private key pair
2. When requesting a token, the client includes a DPoP proof - a signed JWT containing the public key
3. The server binds the issued token to that key (via a `cnf` claim)
4. When using the token at an API, the client must include a new DPoP proof
5. The API verifies the proof signature matches the key in the token's `cnf` claim

### Benefits:
- Stolen tokens can't be used without the private key
- Each proof is bound to a specific HTTP method and URL
- Prevents token replay attacks

## Comparison

| Feature | Standard Auth Code + PKCE | + PAR | + DPoP |
|---------|--------------------------|-------|--------|
| Code interception | Protected (PKCE) | Protected | Protected |
| Parameter tampering | Vulnerable | Protected | Protected |
| Token theft | Vulnerable | Vulnerable | Protected |

## When to Use

- **PAR**: When you need to protect authorization parameters from tampering or when dealing with very long parameter lists
- **DPoP**: When you need to prevent stolen tokens from being reused
- **Both**: For high-security scenarios like financial APIs, where standards like FAPI 2.0 require enhanced security measures including both PAR and proof-of-possession tokens
