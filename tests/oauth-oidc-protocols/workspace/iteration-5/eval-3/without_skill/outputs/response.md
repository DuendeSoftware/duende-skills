# Validating a Reference Token with Token Introspection

## Background

A reference token is an opaque string — unlike a JWT, it doesn't contain any claims or a signature you can validate locally. It's essentially a random identifier that points to token data stored on the authorization server. To validate it, your API has to call the server's **token introspection endpoint** (defined in RFC 7662). The server looks up the token and tells you whether it's active and what claims it carries.

One benefit of reference tokens is that they can be revoked and stop working right away, because every validation is a live lookup on the server. A JWT, on the other hand, stays valid until it expires.

## Using IdentityModel

The IdentityModel library provides an `IntrospectTokenAsync` helper.

```csharp
using IdentityModel.Client;

var client = new HttpClient();

// Discover endpoints so we don't hardcode the introspection URL
var disco = await client.GetDiscoveryDocumentAsync("https://identity.example.com");
if (disco.IsError)
{
    throw new Exception(disco.Error);
}

var introspectionResponse = await client.IntrospectTokenAsync(new TokenIntrospectionRequest
{
    Address = disco.IntrospectionEndpoint,
    ClientId = "catalog-api",
    ClientSecret = "api-secret",
    Token = theIncomingToken
});

if (introspectionResponse.IsError)
{
    throw new Exception(introspectionResponse.Error);
}

if (introspectionResponse.IsActive)
{
    // Token is valid — you can read its claims
    var claims = introspectionResponse.Claims;
}
else
{
    // Token is not valid (expired, revoked, or unknown) — reject the request
}
```

## Notes

- The API authenticates to the introspection endpoint using its own client ID and secret (`catalog-api` / `api-secret`). The introspection endpoint requires authentication so arbitrary parties can't probe tokens.
- The important field is `active` (exposed as `IsActive`). If it's `false`, the token is not valid.
- Calling introspection on every request adds latency, so it's common to cache introspection results for a short time.
- In ASP.NET Core you can also plug an OAuth2 introspection authentication handler into the pipeline so this happens automatically for incoming requests, instead of calling it manually.
