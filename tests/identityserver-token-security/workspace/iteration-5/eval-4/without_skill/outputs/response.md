# Configuring Pushed Authorization Requests (PAR)

PAR is supported in Duende IdentityServer through both a global option and a per-client setting. You can require it for everyone and set a default lifetime, then override the lifetime for a specific client.

## Global configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Require PAR for all authorization requests
    options.PushedAuthorization.Required = true;

    // Default lifetime of a pushed request, in seconds (5 minutes)
    options.PushedAuthorization.Lifetime = 300;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

## Per-client override

```csharp
new Client
{
    ClientId = "banking_app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret("banking_secret".Sha256()) },
    RedirectUris = { "https://banking.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    // Require PAR for this client
    RequirePushedAuthorization = true,

    // Override the global lifetime with 15 minutes (900 seconds)
    PushedAuthorizationLifetime = 900
}
```

## What PAR does

With PAR, the client first POSTs its authorization request parameters directly to IdentityServer's pushed authorization endpoint (back channel). IdentityServer stores them and returns a short-lived `request_uri` handle. The browser redirect then only carries `client_id` and that `request_uri`, instead of the full set of parameters.

Benefits:

- Sensitive parameters (scopes, claims) never appear in the browser URL, so they can't leak via logs, history, or referrer headers.
- Parameters can't be tampered with between the client and the authorization server.
- Redirect URLs stay short.

The **lifetime** controls how long that `request_uri` handle stays valid. 300 seconds (5 minutes) is your global default; `banking_app` gets 900 seconds (15 minutes) because higher-friction banking logins may take longer. Both values are in seconds.

Make sure your license tier includes PAR before relying on it in production.
