# Validating Reference Tokens via Introspection

## What Are Reference Tokens?

Reference tokens are **not self-contained JWTs**. Instead, a reference token is an opaque identifier (a random string) stored server-side by IdentityServer. When your API receives a reference token, it cannot validate it locally — it must call the **introspection endpoint** on IdentityServer to look up the token and determine whether it's valid, what claims it contains, and whether it has been revoked.

### Why Use Reference Tokens?

- **Immediate revocation** — Unlike JWTs, which are valid until expiry (there's no way to invalidate a JWT before its `exp` claim), reference tokens can be revoked immediately because the authorization server checks its database on every introspection call.
- **Sensitive claims** — Token contents are never exposed to intermediaries (proxies, logs, browser dev tools).
- **Token size** — Reference tokens are small opaque strings, whereas JWTs can be large.

## Validating with IdentityModel

Here's how to validate a reference token using the introspection endpoint with IdentityModel:

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
var app = builder.Build();

app.MapGet("/validate-token", async (string accessToken) =>
{
    using var httpClient = new HttpClient();

    // Step 1: Fetch the discovery document to resolve the introspection endpoint
    var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

    if (disco.IsError)
    {
        return Results.Problem($"Discovery document error: {disco.Error}");
    }

    // Step 2: Call the introspection endpoint
    // The API authenticates itself with its own client ID and secret
    var introspectionResponse = await httpClient.IntrospectTokenAsync(
        new TokenIntrospectionRequest
        {
            Address = disco.IntrospectionEndpoint,
            ClientId = "catalog-api",
            ClientSecret = "api-secret",
            Token = accessToken
        });

    if (introspectionResponse.IsError)
    {
        return Results.Problem($"Introspection error: {introspectionResponse.Error}");
    }

    // Step 3: Check if the token is active
    if (!introspectionResponse.IsActive)
    {
        // Token is invalid, expired, or has been revoked
        return Results.Unauthorized();
    }

    // Token is valid — extract claims
    var claims = introspectionResponse.Claims;
    var sub = claims.FirstOrDefault(c => c.Type == "sub")?.Value;
    var scope = claims.FirstOrDefault(c => c.Type == "scope")?.Value;

    return Results.Ok(new { Subject = sub, Scope = scope, Active = true });
});

app.Run();
```

## Key Points

1. **Discovery-based endpoint resolution** — The introspection endpoint URL is resolved from `disco.IntrospectionEndpoint` rather than hardcoded, following the same best practice as token endpoint resolution.

2. **API authenticates with its own credentials** — The `ClientId` and `ClientSecret` in the introspection request are the API's credentials, not the end-user's. The API must be registered as a resource with a secret in IdentityServer.

3. **`IsActive` is the critical check** — The `active` field in the introspection response (exposed as `IsActive`) is what determines token validity. A token may be inactive because it expired, was revoked, or was never valid.

4. **Reference tokens vs JWTs** — Reference tokens are opaque identifiers; they contain no claims themselves. The server stores the token data internally and returns it via introspection. JWTs, by contrast, are self-contained and can be validated locally. The tradeoff is that reference tokens enable immediate revocation, while JWTs are valid until their `exp` claim regardless of revocation.

## Raw HTTP Request

For reference, here's what the introspection call looks like at the protocol level:

```
POST /connect/introspect
Content-Type: application/x-www-form-urlencoded
Authorization: Basic Y2F0YWxvZy1hcGk6YXBpLXNlY3JldA==

token=<reference_token_value>&token_type_hint=access_token
```

The response:
```json
{
    "active": true,
    "sub": "818727",
    "client_id": "web.app",
    "scope": "catalog.read",
    "exp": 1311284570,
    "iss": "https://identity.example.com"
}
```
