# Pushed Authorization Requests (PAR)

## Global configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Endpoints.EnablePushedAuthorizationEndpoint = true;   // default
    options.PushedAuthorization.Required = true;                  // require PAR globally
    options.PushedAuthorization.Lifetime = TimeSpan.FromMinutes(5);
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);
```

PAR requires an additional backing store for pushed requests (in-memory by default; for multiple instances use the distributed cache / EF store).

## Client with its own lifetime

```csharp
new Client
{
    ClientId = "banking_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret("banking_secret".Sha256()) },
    RedirectUris = { "https://bank.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    RequirePushedAuthorization = true,
    PushedAuthorizationLifetime = 900   // seconds = 15 min
}
```

Flow: client authenticates and POSTs authorization parameters to `/connect/par`, gets a `request_uri` and `expires_in`, then redirects the browser to `/connect/authorize?client_id=...&request_uri=...`. Parameters never travel through the browser, so they're integrity-protected and confidential. Global `Required = true` rejects normal authorize requests that don't use PAR.
