# Debugging Token Endpoint Failures

## Systematic Checklist

### 1. Check Discovery Document
Verify `/.well-known/openid-configuration` is accessible and returns valid JSON.

### 2. Verify Client ID
Make sure the client_id in your request exactly matches the registered client on the server. Check for typos and case sensitivity.

### 3. Check Client Secret
The `invalid_client` error usually means the client credentials are wrong:
- Verify the secret matches (check for Sha256 hashing vs plaintext)
- Check for encoding issues or extra whitespace
- Ensure the secret hasn't expired

### 4. Verify Grant Type
Check that the grant type you're using is allowed for this client.

### 5. Check Scopes
Ensure all requested scopes are registered and allowed for the client.

### 6. Redirect URI
For authorization code flow, the redirect_uri must exactly match (including scheme, trailing slashes, etc.).

### 7. Enable Logging
Turn on debug logging on the server to see the exact error message.
