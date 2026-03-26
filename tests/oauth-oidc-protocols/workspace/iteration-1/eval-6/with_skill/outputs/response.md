# Systematic Debugging for Token Endpoint Failures

You're getting `invalid_client` from the token endpoint. Here's a systematic checklist to diagnose the issue:

## 1. Discovery Document

First, verify the token endpoint is reachable:

```
GET https://identity.example.com/.well-known/openid-configuration
```

- Does it return valid JSON?
- Is the `token_endpoint` value what you expect?
- Is the server using HTTPS?

## 2. Client ID Verification

Check that the `client_id` in your request **exactly matches** the server-side client registration:

```csharp
// Your request
ClientId = "web.app"

// Server registration — check for typos, case sensitivity, extra spaces
new Client { ClientId = "web.app" }  // Must match exactly
```

## 3. Client Secret Verification

The `invalid_client` error often means the client secret doesn't match. Common issues:

```csharp
// ❌ Server expects Sha256 hash, but you're sending plaintext
ClientSecrets = { new Secret("correct-secret".Sha256()) }
// The client must send "correct-secret" in the request
// IdentityServer hashes it and compares to the stored hash

// ❌ Secret has leading/trailing whitespace
ClientSecret = " correct-secret "  // trim this

// ❌ URL encoding issues — special characters in the secret
// If using form POST, the secret must be properly URL-encoded
```

Also check:
- Is the secret expired? (secrets can have expiration dates)
- Was the secret recently changed on the server?

## 4. Grant Type

Verify that the grant type in the request is allowed for this client:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,  // Must include the grant type you're requesting
    // ...
}
```

If you're sending `grant_type=authorization_code` but the client only allows `client_credentials`, you'll get an error.

## 5. Scopes

Check that all requested scopes are in the client's `AllowedScopes`:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedScopes = { "openid", "profile", "api1" }
    // If you request "api2" which isn't here, you'll get an error
}
```

Also verify the scopes actually exist as registered `ApiScope` or `IdentityResource` objects on the server.

## 6. Redirect URI

For authorization code flows, the `redirect_uri` in the token request must **exactly match** one of the registered redirect URIs:

```csharp
// Server registration
RedirectUris = { "https://webapp.example.com/callback" }

// ❌ These will ALL fail:
redirect_uri = "https://webapp.example.com/callback/"  // trailing slash
redirect_uri = "http://webapp.example.com/callback"     // HTTP vs HTTPS
redirect_uri = "https://WEBAPP.example.com/callback"    // case mismatch in path
redirect_uri = "https://webapp.example.com:443/callback" // explicit port
```

The match is an **exact string comparison** — scheme, host, port, path, and trailing slash must all match.

## 7. PKCE

Duende IdentityServer requires PKCE by default (`RequirePkce = true`). If your client isn't sending `code_challenge` in the authorize request and `code_verifier` in the token request, the flow will fail.

## 8. Client Authentication Method

Check how the client is sending credentials:
- **POST body**: `client_id` and `client_secret` in the form body
- **Basic auth**: Base64-encoded `client_id:client_secret` in the Authorization header

If the server expects one method but the client uses another, authentication fails.

## 9. Clock Skew

If token validation involves timestamps (e.g., JWT assertions for client authentication), check that server and client clocks are synchronized. The default allowed skew is 5 minutes.

## 10. CORS (Browser Clients)

If calling the token endpoint from a browser (e.g., SPA), verify the origin is in `AllowedCorsOrigins`:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

## Quick Diagnostic

Enable detailed logging on the IdentityServer side:

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Override": {
        "Duende.IdentityServer": "Debug"
      }
    }
  }
}
```

The IdentityServer logs will tell you exactly why the client authentication failed.
