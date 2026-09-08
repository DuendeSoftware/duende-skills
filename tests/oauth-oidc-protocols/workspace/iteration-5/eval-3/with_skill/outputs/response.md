# Validating a Reference Token via Introspection

## Why introspection (and not local JWT validation)

Your API is receiving a **reference token** — an opaque, random identifier, not a self-contained JWT. There are no claims baked into it and no signature to verify locally. The only way to validate it is to ask the issuer: the API calls IdentityServer's **introspection endpoint** (RFC 7662), authenticating itself with its own credentials, and IdentityServer looks the token up in its store and reports whether it is active.

This is the trade-off that makes reference tokens valuable: because validation is a server-side lookup on every call, a revoked token stops working **immediately**. A JWT access token, by contrast, is stateless and remains valid until its `exp` — it cannot be revoked mid-lifetime. Use reference tokens precisely when you need that immediate-revocation capability (or want to keep claims off the wire).

## Code with IdentityModel

```csharp
using IdentityModel.Client;

var authority = "https://identity.example.com";

using var client = new HttpClient();

// 1. Resolve the introspection endpoint from discovery — don't hardcode it
var disco = await client.GetDiscoveryDocumentAsync(authority);
if (disco.IsError)
{
    throw new Exception($"Discovery error: {disco.Error}");
}

// 2. Introspect the reference token. The API authenticates with its OWN
//    client id/secret (this is the API acting as an introspection client).
var response = await client.IntrospectTokenAsync(new TokenIntrospectionRequest
{
    Address = disco.IntrospectionEndpoint,
    ClientId = "catalog-api",
    ClientSecret = "api-secret",
    Token = incomingReferenceToken,
    TokenTypeHint = "access_token"
});

if (response.IsError)
{
    // Network/authentication problem talking to the introspection endpoint
    throw new Exception($"Introspection error: {response.Error}");
}

// 3. The decisive check: is the token active?
if (!response.IsActive)
{
    // Token is expired, revoked, or unknown -> reject the request (401)
    return Results.Unauthorized();
}

// 4. Token is valid — the response also carries the token's claims
var claims = response.Claims; // e.g. sub, scope, client_id, exp
```

## Key points

- **Resolve the endpoint from discovery** (`disco.IntrospectionEndpoint`) rather than hardcoding `/connect/introspect`.
- **`IsActive` is the answer.** `IsError` tells you whether the HTTP/introspection call itself succeeded; `IsActive` (the `active` field in the RFC 7662 response) tells you whether the token is valid. Both must be checked.
- **The API authenticates with its own secret.** Introspection requires the caller to be a registered API resource / introspection client (`catalog-api` / `api-secret`) so that not just anyone can probe tokens.
- On success, `response.Claims` gives you the token's claims (`sub`, `scope`, etc.) for authorization decisions.

## Doing this in ASP.NET Core automatically

Rather than calling introspection by hand on each request, you can wire it into the authentication pipeline with the `Duende.AspNetCore.Authentication.OAuth2Introspection` handler, which performs (and caches) introspection for incoming reference tokens:

```csharp
builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.ClientId = "catalog-api";
        options.ClientSecret = "api-secret";
    });
```

This uses the discovery document to find the introspection endpoint, authenticates with the API's credentials, checks `active`, and populates `HttpContext.User` — with result caching so you're not introspecting on every single request.
