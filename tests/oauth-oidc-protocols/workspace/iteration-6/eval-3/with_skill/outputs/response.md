# Validating a reference token via introspection

A reference token is an opaque handle. It can't be validated locally; the API calls IdentityServer's introspection endpoint, authenticating with its own credentials (`catalog-api` / `api-secret`). Resolve the endpoint from discovery, don't hardcode it.

## Manual call (IdentityModel)
```csharp
using IdentityModel.Client;

app.MapGet("/validate", async (HttpContext ctx, IHttpClientFactory factory) =>
{
    var accessToken = ctx.Request.Headers.Authorization.ToString().Replace("Bearer ", "");
    var http = factory.CreateClient();

    var disco = await http.GetDiscoveryDocumentAsync("https://identity.example.com");
    if (disco.IsError) return Results.Problem(disco.Error);

    var response = await http.IntrospectTokenAsync(new TokenIntrospectionRequest
    {
        Address = disco.IntrospectionEndpoint,
        ClientId = "catalog-api",
        ClientSecret = "api-secret",
        Token = accessToken
    });

    if (response.IsError) return Results.Problem(response.Error);
    if (!response.IsActive) return Results.Unauthorized(); // invalid, expired or revoked

    return Results.Ok(response.Claims.Select(c => new { c.Type, c.Value }));
});
```
The wire format:
```
POST /connect/introspect
Authorization: Basic base64(catalog-api:api-secret)
Content-Type: application/x-www-form-urlencoded

token=<reference_token>&token_type_hint=access_token
```
→ `{"active":true,"scope":"catalog.read","client_id":"...","sub":"..."}` or `{"active":false}`.

## Recommended: let middleware do it
```csharp
// Duende.AspNetCore.Authentication.OAuth2Introspection
builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", o =>
    {
        o.Authority = "https://identity.example.com";
        o.ClientId = "catalog-api";
        o.ClientSecret = "api-secret";
    });
builder.Services.AddAuthorization();
app.UseAuthentication(); app.UseAuthorization();
```
The handler discovers the endpoint, caches results, and builds the `ClaimsPrincipal`.

## Server side
`catalog-api` must be an `ApiResource`/`ApiScope` with `ApiSecrets = { new Secret("api-secret".Sha256()) }` and the client must request that scope. Why reference tokens: sensitive claims stay server-side and revocation is immediate (JWTs can't be revoked until `exp`). Keep secrets out of source control.
