# PAR and DPoP

## PAR (RFC 9126)
Instead of putting parameters in the browser redirect URL, the client POSTs them directly to the server's `/connect/par` endpoint (authenticating as a client), and gets back a `request_uri`. The browser is redirected with only `client_id` and `request_uri`.

Benefits:
- Request parameters are integrity protected and confidential (no tampering via URL, no leakage of sensitive scopes/claims/authorization_details).
- Client is authenticated before the user interaction starts.
- No URL length limits; fits RAR (rich authorization requests).
- Server can reject bad requests early.

## DPoP (RFC 9449)
Demonstrating Proof-of-Possession binds tokens to a key held by the client. The client generates a key pair and, with every token request and API call, sends a signed `DPoP` JWT (contains HTTP method, URL, timestamp, `jti`, and access token hash `ath`). The access token carries a `cnf.jkt` thumbprint of the key. Resource servers verify the proof matches.

Benefit: a stolen access/refresh token is useless without the private key (standard bearer tokens work for anyone holding them). Mitigates replay and exfiltration, especially for SPAs and public clients.

## When needed
- High-security sectors (FAPI, open banking, healthcare, government).
- Sensitive scopes/transactions, RAR payments.
- Public clients where tokens might leak (SPAs, mobile).
- Otherwise, code+PKCE is typically enough for ordinary apps.

## Compared to code + PKCE
PKCE protects the code exchange from interception/injection but nothing afterwards: tokens remain bearer tokens, and authorize request parameters are exposed in the front channel. PAR hardens the authorization request; DPoP hardens token usage. They complement PKCE.

## Duende IdentityServer
```csharp
builder.Services.AddIdentityServer(o => {
    o.Endpoints.EnablePushedAuthorizationEndpoint = true; // PAR
});
// client
new Client {
  ClientId = "web", RequireDPoP = true, RequirePushedAuthorization = true,
  AllowedGrantTypes = GrantTypes.Code, ...
}
```
ASP.NET Core 9+ OIDC handler supports PAR out of the box (`PushedAuthorizationBehavior`); DPoP for clients via `Duende.AccessTokenManagement.DPoP`, APIs via `AddJwtBearer(...).AddDPoP()` from `Duende.AspNetCore.Authentication.JwtBearer`.
