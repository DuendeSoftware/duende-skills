# Debugging `invalid_client` at the token endpoint

`invalid_client` means client authentication failed: the server doesn't recognize the client or couldn't verify its credentials. It's raised *before* grant validation, so the code/redirect URI are not the problem yet.

## Systematic checklist
1. **Read the server logs** (set `Duende.IdentityServer` to Debug). They state exactly why: unknown client, no secret, secret mismatch, client disabled.
2. **Client ID**: exact, case-sensitive match (`web.app`). Is the client present in the store/config and `Enabled = true`?
3. **Secret storage**: IdentityServer stores *hashed* secrets. Config must use `new Secret("correct-secret".Sha256())`. Putting the plain text, or hashing with Sha512 in config but sending something else, causes mismatch. Check for trailing whitespace/newlines, or User-Secrets/env values differing from what you believe.
4. **Client type**: if `RequireClientSecret = true` and the client sends no secret → invalid_client. A public SPA client shouldn't send one.
5. **Authentication method**: the client must send credentials the way the server accepts them:
   - Basic header: `Authorization: Basic base64(urlencode(id):urlencode(secret))`
   - Or POST body `client_id` & `client_secret`
   Special characters in the id/secret must be URL-encoded before Base64. Don't send both differently.
6. **Environment mismatch**: wrong authority/environment (staging secret against prod), different issuer, or multiple IdentityServer instances.
7. **Secret expiration**: `Expiration` on the Secret in the past.
8. **Request shape**: `Content-Type: application/x-www-form-urlencoded` POST to the endpoint from discovery.
9. **Grant allowed**: unauthorized grant types give `unauthorized_client`, not invalid_client, but check `AllowedGrantTypes` anyway.
10. **Reproduce in isolation** with curl/Postman:
```
curl -v -X POST https://identity.example.com/connect/token \
  -u "web.app:correct-secret" \
  -d grant_type=authorization_code -d code=... -d redirect_uri=... -d code_verifier=...
```
or with client credentials to verify the secret alone:
```csharp
var r = await http.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest {
    Address = disco.TokenEndpoint, ClientId = "web.app", ClientSecret = "correct-secret", Scope = "api1" });
Console.WriteLine(r.Error + " " + r.ErrorDescription);
```
Server-side config for reference:
```csharp
new Client {
  ClientId = "web.app",
  ClientSecrets = { new Secret("correct-secret".Sha256()) },
  AllowedGrantTypes = GrantTypes.Code,
  RedirectUris = { "https://app/signin-oidc" },
  AllowedScopes = { "openid", "profile" }
}
```
Other errors: `invalid_grant` (bad/expired/reused code, PKCE mismatch, redirect_uri mismatch), `invalid_scope`, `unauthorized_client`, `invalid_request` (missing parameter).
