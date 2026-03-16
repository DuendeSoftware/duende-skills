# Debugging Token Endpoint Failures

An `invalid_client` error from the token endpoint means the server couldn't authenticate your client. Here's a systematic approach to debug this:

## 1. Check Client ID

Make sure the client ID `web.app` matches exactly on both the server and client side. This is case-sensitive.

## 2. Verify Client Secret

The most common cause of `invalid_client` is a wrong or mismatched secret. Verify:
- The secret value is correct
- The secret hasn't expired (if time-limited secrets are configured)
- There are no encoding issues when sending the secret

## 3. Check Grant Type

Ensure the grant type you're requesting (e.g., `authorization_code`, `client_credentials`) is allowed for this client on the server.

## 4. Verify Scopes

Make sure all requested scopes are configured as allowed for this client.

## 5. Check Redirect URI

For authorization code flows, the redirect URI must match exactly — including the trailing slash, scheme (http/https), and port number.

## 6. Check Token Endpoint URL

Make sure you're hitting the correct token endpoint. You can find it in the OpenID Connect discovery document at `/.well-known/openid-configuration`.

## 7. HTTPS Configuration

Ensure you're using HTTPS for all endpoints in production. HTTP may work in development but could cause issues.

## 8. Check Server Logs

The identity server will typically log more detailed error information. Check the server-side logs for specific error messages about why the client authentication failed.

## 9. Network / CORS Issues

If calling from a browser, check for CORS errors in the browser console. The token endpoint must allow requests from your application's origin.

## Testing

```bash
# Test the discovery document
curl https://identity.example.com/.well-known/openid-configuration

# Test token endpoint directly
curl -X POST https://identity.example.com/connect/token \
  -d "grant_type=client_credentials&client_id=web.app&client_secret=correct-secret"
```
