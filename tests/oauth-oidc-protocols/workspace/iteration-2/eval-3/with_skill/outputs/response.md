# Validating Reference Tokens via Introspection

## What Are Reference Tokens?

Reference tokens are **opaque identifiers** — they are not self-contained JWTs. Instead of containing claims directly, a reference token is a random string that acts as a handle. The actual token data is stored server-side in IdentityServer's persisted grant store.

Because reference tokens are opaque, the API **cannot validate them locally** by checking a signature and reading claims. Instead, the API must call the **introspection endpoint** to ask IdentityServer whether the token is valid and to retrieve the associated claims.

### Key Advantage: Immediate Revocation

Unlike JWTs, which are valid until they expire (the API has no way to know a JWT has been revoked without checking back with the server), **reference tokens enable immediate revocation**. When a reference token is revoked at IdentityServer, the next introspection call will return `active: false`.

## Introspection with IdentityModel

Here's how to call the introspection endpoint using IdentityModel:

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization();

var app = builder.Build();

app.MapGet("/validate-token", async (HttpRequest request) =>
{
    // Extract the token from the Authorization header
    var accessToken = request.Headers.Authorization.ToString().Replace("Bearer ", "");

    if (string.IsNullOrEmpty(accessToken))
    {
        return Results.Unauthorized();
    }

    using var httpClient = new HttpClient();

    // Step 1: Fetch the discovery document to resolve the introspection endpoint
    var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

    if (disco.IsError)
    {
        return Results.Problem($"Discovery error: {disco.Error}");
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

    // Step 3: Check if the token is active (valid, not expired, not revoked)
    if (!introspectionResponse.IsActive)
    {
        return Results.Json(new { error = "Token is inactive (expired, revoked, or invalid)" },
            statusCode: 401);
    }

    // Token is valid — read the claims from the introspection response
    var claims = introspectionResponse.Claims;
    var clientId = claims.FirstOrDefault(c => c.Type == "client_id")?.Value;
    var scope = claims.FirstOrDefault(c => c.Type == "scope")?.Value;

    return Results.Ok(new
    {
        active = true,
        client_id = clientId,
        scope = scope,
        claims = claims.Select(c => new { c.Type, c.Value })
    });
});

app.MapGet("/", () => "Hello World!");

app.Run();
```

## How It Works

1. **Discovery**: The API fetches the discovery document from the authority to resolve the introspection endpoint URL (`disco.IntrospectionEndpoint`).

2. **Introspection Request**: The API POSTs the token to the introspection endpoint, authenticating itself with its own `ClientId` and `ClientSecret`. The introspection endpoint is protected — only registered API resources/clients can call it.

3. **IsActive Check**: The `IsActive` property (corresponding to the `active` field in the JSON response per RFC 7662) indicates whether the token is currently valid. A token may be inactive if it's expired, revoked, or was never valid.

## When to Use Reference Tokens vs JWTs

| Aspect | JWT (Self-Contained) | Reference Token |
|--------|---------------------|-----------------|
| Validation | Local (signature check) | Remote (introspection) |
| Revocation | Not immediate (valid until expiry) | Immediate |
| Token size | Large (contains all claims) | Small (opaque string) |
| Network dependency | None for validation | Requires IdentityServer to be reachable |
| Sensitive claims | Exposed to intermediaries | Kept server-side |
