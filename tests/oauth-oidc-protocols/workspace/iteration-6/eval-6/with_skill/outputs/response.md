# Debugging `invalid_client` at the token endpoint

`invalid_client` is raised at **client authentication**, before code/redirect/PKCE are examined. So focus on client ID, secret, and how credentials are sent. Note "correct-secret" being correct *in your app* doesn't prove the server has the same value.

## Ordered checklist
1. **Server logs first** (`Duende.IdentityServer` at Debug): they say whether the client was unknown, disabled, or secret mismatched.
2. **Discovery**: confirm authority and that you POST to `token_endpoint` from `/.well-known/openid-configuration` (right environment/instance).
3. **Client ID**: exactly `web.app`, case-sensitive; client exists and `Enabled = true`.
4. **Client secret**: IdentityServer stores **hashed** secrets. Registration must be `new Secret("correct-secret".Sha256())`, not plaintext. Look for encoding problems, trailing newline/whitespace, wrong environment value, or an expired secret (`Expiration`).
5. **How you send it**: Basic header `Authorization: Basic base64(urlencode(id):urlencode(secret))` or form fields `client_id`/`client_secret`, not mixed; content type `application/x-www-form-urlencoded`.
6. **`RequireClientSecret`** vs. client type: a public client (no secret) sending a secret or confidential client sending none both fail.
7. Only then move on to the grant-level checks (these give `invalid_grant`, `invalid_scope`, `unauthorized_client`):
   - **Redirect URI** exact match (scheme, host, port, path, trailing slash)
   - **Scopes** in `AllowedScopes`
   - **Grant type** in `AllowedGrantTypes`
   - **PKCE**: `code_challenge`/`code_verifier` (required by default)
   - **Code** single-use, not expired
8. **Clock skew** (default 5 min) and **HTTPS**; **CORS** (`AllowedCorsOrigins`) if called from a browser.

## Isolate the secret
```csharp
var disco = await http.GetDiscoveryDocumentAsync("https://identity.example.com");
var r = await http.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
{
    Address = disco.TokenEndpoint,
    ClientId = "web.app",
    ClientSecret = "correct-secret",
    Scope = "api1"
});
Console.WriteLine($"{r.Error} {r.ErrorDescription}");
```
(If the client isn't allowed that grant you'd get `unauthorized_client` rather than `invalid_client`, which itself proves authentication passed.)

Reference server config:
```csharp
new Client
{
    ClientId = "web.app",
    ClientSecrets = { new Secret("correct-secret".Sha256()) },
    AllowedGrantTypes = GrantTypes.Code,
    RedirectUris = { "https://app.example.com/signin-oidc" },
    AllowedScopes = { "openid", "profile", "api1" }
}
```
Most common culprit: plaintext secret in the server config, or a different secret in the environment actually deployed.
