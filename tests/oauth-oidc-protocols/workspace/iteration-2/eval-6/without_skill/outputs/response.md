# Debugging Token Endpoint Failures

An `invalid_client` error usually means the server couldn't authenticate the client. Here's a systematic approach:

## 1. Verify the Discovery Document

First, check that the OpenID Connect discovery document is reachable:

```bash
curl https://identity.example.com/.well-known/openid-configuration
```

Make sure it returns valid JSON with the expected endpoints.

## 2. Check Client ID

Verify the client ID (`web.app`) exactly matches what's registered on the server. Client IDs are case-sensitive, so check for typos and whitespace.

## 3. Check Client Secret

The `invalid_client` error most commonly means the secret is wrong. Common issues:
- The secret might need to be hashed (some servers store SHA256 hashes)
- Encoding problems during transmission
- The secret may have expired

## 4. Verify Grant Type

Make sure the grant type you're requesting is allowed for this client. If the client only allows `authorization_code` but you're sending `client_credentials`, it will fail.

## 5. Check Scopes

Verify all requested scopes are registered and allowed for this client.

## 6. Redirect URI Match

For authorization code flow, the redirect URI must be an exact match:
- Same scheme (http vs https)
- Same host
- Same port
- Same path
- Same trailing slash (or lack thereof)

## 7. Check PKCE

Many modern authorization servers require PKCE. Make sure you're sending `code_challenge` in the authorize request and `code_verifier` in the token request.

## 8. Clock Skew

Check that the server's clock is reasonably synchronized. Large time differences can cause token validation failures.

## 9. HTTPS

Ensure you're using HTTPS. Some servers reject HTTP requests entirely.

## 10. CORS

If you're calling the token endpoint from a browser, make sure your origin is allowed in the server's CORS configuration.

## Quick Tips

- Enable verbose logging on the server for more detailed error messages
- Test with curl or Postman to isolate from application code
- Double-check everything character by character - typos are the most common cause
