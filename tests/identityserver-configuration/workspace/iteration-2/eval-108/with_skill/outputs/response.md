# Adding an Audience Claim Without Full API Resources

The simplest way to get an `aud` (audience) claim in your access tokens when you only have a single API is to enable the `EmitStaticAudienceClaim` option. This adds a static audience claim with the value `{issuer}/resources` to all access tokens.

## Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;

    // Emit a static audience claim: {issuer}/resources
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryClients(new Client[]
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
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How It Works

When `EmitStaticAudienceClaim` is set to `true`, every access token issued by IdentityServer will include:

```json
{
  "aud": "https://your-identity-server/resources",
  "scope": "api1"
}
```

The audience value is always `{issuer}/resources` — a fixed string based on your IdentityServer's issuer URI.

## When to Use This vs API Resources

| Approach | Use When |
|----------|----------|
| `EmitStaticAudienceClaim = true` | Single API, just need *some* audience claim for token validation |
| `ApiResource` definition | Multiple APIs needing audience isolation, per-API signing, or introspection |

### Alternative: Define a Minimal API Resource

If you want a more targeted audience claim specific to your API, you can define an `ApiResource` instead:

```csharp
.AddInMemoryApiResources(new ApiResource[]
{
    new ApiResource("my-api", "My API")
    {
        Scopes = { "api1" }
    }
})
```

This would set `"aud": "my-api"` in the token, giving you a specific audience value. However, for a single API where you just need the claim to exist, `EmitStaticAudienceClaim` is the simplest option.
