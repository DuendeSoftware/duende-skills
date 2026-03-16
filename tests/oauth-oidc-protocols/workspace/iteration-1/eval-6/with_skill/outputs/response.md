# Debugging Token Endpoint Failures — Systematic Checklist

Getting an `invalid_client` error from the token endpoint means the authorization server cannot authenticate or identify your client. Here's a systematic debugging approach, following the protocol debugging checklist:

## Step 1: Verify the Discovery Document

Check that `/.well-known/openid-configuration` at `https://identity.example.com` is reachable and returns valid JSON:

```bash
curl https://identity.example.com/.well-known/openid-configuration | jq .
```

Verify the `token_endpoint`, `authorization_endpoint`, and `issuer` values are correct. If this fails, all subsequent steps are moot — the server may be down or misconfigured.

## Step 2: Verify Client ID Match

Ensure the client ID `web.app` in your request **exactly matches** the server registration. This is case-sensitive. Common issues:
- Extra whitespace or invisible characters
- Copy-paste encoding issues
- Different environments using different client IDs

```csharp
// Check: does this match the server's client registration exactly?
ClientId = "web.app"
```

## Step 3: Check the Client Secret

The `invalid_client` error most commonly means the secret is wrong. Check:

- **Encoding issues** — Is the secret hashed with SHA256 on the server? If the server stores `"secret".Sha256()`, you must send the plaintext `"correct-secret"` — IdentityModel and the token endpoint handle the hashing. But if the server registration has the plaintext and you're sending a hash, it won't match.
- **Plaintext vs. Sha256 hash mismatch** — On the server side:

```csharp
// Server registration — the secret is stored as a SHA256 hash
ClientSecrets = { new Secret("correct-secret".Sha256()) }

// The client must send the plaintext secret; the server hashes it for comparison
// If the client sends a pre-hashed value, it will be double-hashed and fail
```

- **Client credential style** — Is the secret sent in the Authorization header (default) or as a POST body parameter? The server and client must agree.

## Step 4: Verify Allowed Grant Types

Check that the grant type you're requesting is allowed on the client:

```csharp
// Server configuration
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code, // Does this include the grant type you're using?
    // ...
}
```

If you're sending `grant_type=authorization_code`, the client must have `GrantTypes.Code` (or `GrantTypes.CodeAndClientCredentials`). If you're sending `grant_type=client_credentials`, it must have `GrantTypes.ClientCredentials`.

## Step 5: Verify Allowed Scopes

Ensure all requested scopes are registered in `AllowedScopes` on the client:

```csharp
AllowedScopes = { "openid", "profile", "api1" }
// If you request a scope not in this list, the request will fail
```

## Step 6: Check Redirect URI (Exact String Match)

For authorization code flows, the redirect URI must be an **exact string match** including:
- Scheme (`https://` vs `http://`)
- Host and port (`localhost:5001` vs `localhost:5000`)
- Path (`/callback` vs `/callback/`)
- **Trailing slash matters!**

```csharp
// Server
RedirectUris = { "https://app.example.com/callback" }

// Client — must match exactly
options.CallbackPath = "/callback"; // becomes https://app.example.com/callback
```

## Step 7: Verify PKCE

Duende IdentityServer requires PKCE by default (`RequirePkce = true`). If your client isn't sending `code_challenge` and `code_verifier`, the request will be rejected. ASP.NET Core's OIDC handler sends PKCE automatically since .NET 7.

## Step 8: Check Clock Skew

Token validation allows a default clock skew of 5 minutes. If the server and client clocks are significantly out of sync, tokens may be rejected as expired before they're used.

## Step 9: Verify HTTPS

Ensure the authorize redirect is using HTTPS. Mixed content (HTTP/HTTPS mismatch) can cause silent failures, especially in browsers that block mixed content.

## Step 10: Check CORS (Browser Clients)

If calling the token endpoint from a browser (e.g., SPA), verify the origin is registered in `AllowedCorsOrigins` on the client:

```csharp
AllowedCorsOrigins = { "https://app.example.com" }
```

Without proper CORS configuration, the browser will block the response with a CORS error that may manifest as a cryptic failure.

## Quick Diagnostic Commands

```bash
# Test discovery document
curl -s https://identity.example.com/.well-known/openid-configuration | jq .

# Test token endpoint directly
curl -s -X POST https://identity.example.com/connect/token \
  -d "grant_type=client_credentials&client_id=web.app&client_secret=correct-secret&scope=api1"

# Check server logs — Duende IdentityServer logs detailed error information
# Look for the Duende.IdentityServer category in your logging output
```
