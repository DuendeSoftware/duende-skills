# Systematic Debugging Checklist for Token Endpoint Failures

An `invalid_client` error from the token endpoint means IdentityServer couldn't authenticate the client. Here's a systematic approach to diagnose the issue:

## 1. Check the Discovery Document

Verify that `/.well-known/openid-configuration` is reachable and returns valid JSON:

```bash
curl https://identity.example.com/.well-known/openid-configuration
```

If this fails, the IdentityServer itself is misconfigured or unreachable. Check:
- Is the server running?
- Is the base URL / authority correct?
- Are there DNS or firewall issues?

## 2. Verify the Client ID

The `client_id` in the request must **exactly match** the server registration. Check for:
- Typos
- Case sensitivity (client IDs are case-sensitive)
- Leading/trailing whitespace
- The client being registered in the wrong environment (dev vs. production)

```csharp
// In your IdentityServer client configuration
new Client
{
    ClientId = "web.app",  // Must exactly match what the client sends
    ...
}
```

## 3. Check the Client Secret

The `invalid_client` error most commonly means **the secret doesn't match**. Check for:

- **Hash mismatch**: IdentityServer stores secrets as SHA256 hashes. If you accidentally stored the plaintext secret instead of calling `.Sha256()`, or vice versa, authentication will fail.

```csharp
// ✅ CORRECT — Store the SHA256 hash
ClientSecrets = { new Secret("correct-secret".Sha256()) }

// ❌ WRONG — Storing plaintext when IdentityServer expects a hash
ClientSecrets = { new Secret("correct-secret") }
```

- **Encoding issues**: Ensure the secret isn't being URL-encoded or modified during transmission
- **Shared secrets expiration**: Check if `Secret.Expiration` has passed

## 4. Verify Grant Type

Is the grant type in the request allowed by the client's `AllowedGrantTypes`?

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,  // Only allows authorization_code
    // If the client sends grant_type=client_credentials, this will fail
}
```

## 5. Check Allowed Scopes

Are all requested scopes registered in `AllowedScopes` on the client? Requesting a scope that isn't allowed returns an error.

```csharp
new Client
{
    ClientId = "web.app",
    AllowedScopes = { "openid", "profile", "api1" },
    // Requesting "api2" would fail
}
```

## 6. Verify Redirect URI (for authorization code flow)

The redirect URI must be an **exact string match** including:
- Scheme (`https://` vs `http://`)
- Host name
- Port number (even default ports like :443)
- Path
- **Trailing slash** (`/signin-oidc` is not the same as `/signin-oidc/`)

```csharp
new Client
{
    RedirectUris = { "https://myapp.example.com/signin-oidc" },
    // "https://myapp.example.com/signin-oidc/" would NOT match (trailing slash)
}
```

## 7. Verify PKCE

Duende IdentityServer requires PKCE by default (`RequirePkce = true`). If the client isn't sending `code_challenge` and `code_verifier`, the token exchange will fail.

- ASP.NET Core's OIDC handler sends PKCE automatically since .NET 7
- If using a custom client, ensure you generate `code_verifier` and `code_challenge`

## 8. Check Clock Skew

Token validation allows a default 5-minute clock skew. If the server's clock is significantly off from the client's clock, token validation and nonce checks can fail.

```bash
# Verify server time
date -u
```

## 9. Verify HTTPS

Is the authorize redirect using HTTPS? Mixed content (HTTP authority with HTTPS redirect) can cause silent failures. Browsers may block the redirect entirely.

## 10. Check CORS (Browser-Based Clients)

If calling the token endpoint from a browser (e.g., SPA or JavaScript client), verify the origin is in `AllowedCorsOrigins`:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedCorsOrigins = { "https://myapp.example.com" },
}
```

Without CORS, the browser will block the token endpoint response.

## Quick Diagnostic Steps

1. **Enable server-side logging** — Set IdentityServer events to verbose and check the server logs. The error message on the server side is usually far more descriptive than the `invalid_client` response.
2. **Use the discovery document** — Always resolve endpoints from `/.well-known/openid-configuration` rather than hardcoding URLs.
3. **Test with curl/Postman** — Isolate the token request from your application code to rule out client-side issues.
