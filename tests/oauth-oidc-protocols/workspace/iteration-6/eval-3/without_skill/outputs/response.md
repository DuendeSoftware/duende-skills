# Validating reference tokens via introspection

Reference tokens can't be validated locally; the API asks IdentityServer via the introspection endpoint (RFC 7662), authenticating as the API resource/client (`catalog-api` / `api-secret`).

## Easiest: the handler
```csharp
// dotnet add package Duende.AspNetCore.Authentication.OAuth2Introspection
builder.Services.AddAuthentication("token")
    .AddOAuth2Introspection("token", o =>
    {
        o.Authority = "https://identity.example.com";
        o.ClientId = "catalog-api";
        o.ClientSecret = "api-secret";
    });
builder.Services.AddAuthorization();

app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/catalog", () => "ok").RequireAuthorization();
```

## Manual call with IdentityModel
```csharp
using IdentityModel.Client;

app.MapGet("/check", async (HttpContext ctx, IHttpClientFactory f) =>
{
    var token = ctx.Request.Headers.Authorization.ToString().Replace("Bearer ", "");
    var client = f.CreateClient();

    var disco = await client.GetDiscoveryDocumentAsync("https://identity.example.com");
    if (disco.IsError) return Results.Problem(disco.Error);

    var result = await client.IntrospectTokenAsync(new TokenIntrospectionRequest
    {
        Address = disco.IntrospectionEndpoint,
        ClientId = "catalog-api",
        ClientSecret = "api-secret",
        Token = token
    });

    if (result.IsError) return Results.Problem(result.Error);
    if (!result.IsActive) return Results.Unauthorized();

    return Results.Ok(result.Claims.Select(c => new { c.Type, c.Value }));
});
```

Raw HTTP:
```
POST /connect/introspect
Authorization: Basic base64(catalog-api:api-secret)
Content-Type: application/x-www-form-urlencoded

token=<reference token>
```
Response `{"active":true,"scope":"catalog.read","client_id":"...","sub":"..."}` or `{"active":false}`.

On the IdentityServer side, `catalog-api` must be defined as an `ApiResource`/`ApiScope` with a secret (hashed with `.Sha256()`), and the token must contain that audience/scope. Cache introspection results briefly for performance (the handler supports caching), and keep the secret in configuration, not source.
