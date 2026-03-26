# Validating Reference Tokens via Introspection

## What Are Reference Tokens?

Reference tokens are **opaque identifiers** — they are not self-contained JWTs. When an API receives a reference token, it cannot validate it locally by checking the signature and claims. Instead, the API must call the IdentityServer's **introspection endpoint** to determine if the token is valid, who it belongs to, and what scopes it has.

**Key advantage:** Reference tokens enable **immediate revocation**. Unlike JWTs, which are valid until their expiry time regardless of server-side state, revoking a reference token takes effect immediately because the introspection endpoint checks the current token status on every call.

## Introspection Code

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Step 1: Fetch the discovery document to find the introspection endpoint
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

if (disco.IsError)
{
    Console.WriteLine($"Discovery error: {disco.Error}");
    return;
}

// Step 2: Introspect the reference token
var introspectionResponse = await httpClient.IntrospectTokenAsync(
    new TokenIntrospectionRequest
    {
        Address = disco.IntrospectionEndpoint,
        ClientId = "catalog-api",
        ClientSecret = "api-secret",
        Token = referenceToken  // The opaque token string received from the client
    });

if (introspectionResponse.IsError)
{
    Console.WriteLine($"Introspection error: {introspectionResponse.Error}");
    return;
}

// Step 3: Check if the token is active
if (!introspectionResponse.IsActive)
{
    Console.WriteLine("Token is not active (expired, revoked, or invalid)");
    return;
}

// Token is valid — read claims
var sub = introspectionResponse.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
var scope = introspectionResponse.Claims.FirstOrDefault(c => c.Type == "scope")?.Value;
var clientId = introspectionResponse.Claims.FirstOrDefault(c => c.Type == "client_id")?.Value;

Console.WriteLine($"Subject: {sub}, Scope: {scope}, Client: {clientId}");
```

## How It Works

1. **Discovery**: The introspection endpoint URL is resolved from the discovery document (`disco.IntrospectionEndpoint`), not hardcoded.

2. **API Authentication**: The API authenticates itself to the introspection endpoint using its own `ClientId` and `ClientSecret`. This ensures that only authorized APIs can introspect tokens.

3. **Token Validation**: The `IsActive` property is the critical check — it returns `true` only if the token is valid, not expired, and not revoked.

## JWT vs Reference Tokens

| | JWT | Reference Token |
|---|---|---|
| **Format** | Self-contained signed JSON | Opaque string identifier |
| **Validation** | Local (signature + claims check) | Server-side (introspection) |
| **Revocation** | Not revocable until expiry | Immediately revocable |
| **Network** | No extra calls needed | Requires introspection call per request |
| **Size** | Can be large (many claims) | Small (opaque handle) |
