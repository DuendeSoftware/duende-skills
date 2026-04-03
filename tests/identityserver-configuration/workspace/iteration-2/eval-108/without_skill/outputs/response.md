# Getting an Audience Claim in Access Tokens

If your access tokens don't have an `aud` claim, you need to define an API Resource. The audience claim comes from the API Resource configuration.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("api1")
    })
    .AddInMemoryApiResources(new[]
    {
        new ApiResource("my-api")
        {
            Scopes = { "api1" }
        }
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "my-client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## Explanation

The `ApiResource` groups API scopes under a logical API and controls the `aud` claim in the JWT. When you define an `ApiResource` with name `"my-api"` and include your scope in it, tokens will contain:

```json
{
  "aud": "my-api",
  "scope": "api1"
}
```

Your API can then validate the audience claim matches what it expects, providing an additional layer of security.

Even with just one API, defining the resource is the standard approach. The resource name becomes the audience value.
