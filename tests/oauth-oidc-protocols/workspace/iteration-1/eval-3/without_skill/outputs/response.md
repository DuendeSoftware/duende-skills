# Validating Reference Tokens via Introspection

When your API receives an opaque (reference) token rather than a JWT, you need to validate it by calling the introspection endpoint. Reference tokens are opaque strings that don't contain any claims — they're just identifiers. The authorization server holds the actual token data server-side.

## Using IdentityModel

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Fetch the discovery document to find the introspection endpoint
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

if (disco.IsError)
{
    Console.WriteLine($"Error: {disco.Error}");
    return;
}

// Call the introspection endpoint
var response = await httpClient.IntrospectTokenAsync(new TokenIntrospectionRequest
{
    Address = disco.IntrospectionEndpoint,
    ClientId = "catalog-api",
    ClientSecret = "api-secret",
    Token = referenceToken
});

if (response.IsError)
{
    Console.WriteLine($"Error: {response.Error}");
    return;
}

// Check if the token is active
if (response.IsActive)
{
    Console.WriteLine("Token is valid");
    // Access claims from the introspection response
    var sub = response.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
}
else
{
    Console.WriteLine("Token is not active (invalid, expired, or revoked)");
}
```

## How It Works

1. The API receives an opaque token string in the `Authorization: Bearer` header
2. The API calls the introspection endpoint, authenticating with its own client ID and secret
3. The authorization server looks up the token and returns whether it's active along with associated claims
4. The API checks `IsActive` (the `active` field in the JSON response) to determine validity

## Reference Tokens vs JWTs

Reference tokens are opaque identifiers — they are not self-contained JWTs. You cannot decode them locally. Instead, validation requires a network call to the introspection endpoint on every request (though results can be cached).

The advantage is that reference tokens can be revoked immediately. With JWTs, once issued, they remain valid until their expiration time — there's no way to revoke them before they expire. Reference tokens give you instant revocation capability since the server checks its database on each introspection call.
