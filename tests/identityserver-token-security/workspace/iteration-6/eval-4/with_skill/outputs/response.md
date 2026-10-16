# Pushed Authorization Requests (PAR)

PAR (Business and Enterprise editions, ≥ 7.0) moves authorization parameters from front-channel redirects to a back-channel POST, preventing leakage and tampering and keeping URLs short.

## Global configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.PushedAuthorization.Required = true;   // require PAR globally
    options.PushedAuthorization.Lifetime = 300;    // seconds (int, not TimeSpan) = 5 minutes
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);
```

## `banking_app` with a 15-minute override

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
    PushedAuthorizationLifetime = 900   // seconds = 15 minutes, overrides global
}
```

| Property | Default | Description |
|---|---|---|
| `PushedAuthorization.Required` | `false` | Global requirement |
| `PushedAuthorization.Lifetime` | `600` s (`int`) | Request lifetime |
| `PushedAuthorization.AllowUnregisteredPushedRedirectUris` | `false` | |
| `Client.RequirePushedAuthorization` | `false` | Per-client |
| `Client.PushedAuthorizationLifetime` | `null` | Per-client override |
| `Endpoints.EnablePushedAuthorizationEndpoint` | `true` | |

Pitfall: too short a lifetime breaks users who take time to authenticate (MFA, consent) — hence the longer value for `banking_app`. In the Starter edition PAR isn't processed; set `Endpoints.EnablePushedAuthorizationEndpoint = false` there.

## ASP.NET client (.NET 9+)
```csharp
.AddOpenIdConnect("oidc", o =>
{
    o.PushedAuthorizationBehavior = PushedAuthorizationBehavior.Require;
});
```
