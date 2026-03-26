# PAR and DPoP

## Pushed Authorization Requests (PAR)

PAR is an OAuth extension where the client sends authorization parameters to the server via a backchannel POST request instead of putting them in the authorization URL. The server returns a `request_uri` that the client uses in the actual authorization redirect.

Benefits:
- Parameters aren't exposed in the URL
- Prevents parameter tampering
- Avoids URL length limitations

## DPoP (Demonstrating Proof-of-Possession)

DPoP binds tokens to a cryptographic key held by the client. The client creates a key pair and includes a proof JWT in requests. The server binds the access token to the client's public key via a confirmation claim.

Benefits:
- Stolen tokens can't be used without the private key
- Each request includes a fresh proof
- Stronger than bearer tokens

## When to Use Them

These are advanced security mechanisms typically needed for:
- Financial APIs (FAPI compliance)
- High-security environments
- Regulatory requirements

They add security beyond standard authorization code + PKCE by protecting against parameter tampering (PAR) and token theft (DPoP).
