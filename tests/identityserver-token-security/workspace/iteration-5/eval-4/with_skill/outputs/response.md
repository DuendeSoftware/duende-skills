# Configuring Pushed Authorization Requests (PAR)

PAR is controlled in two places: globally through the IdentityServer options, and per-client. Lifetimes are expressed in **seconds as an `int`** (not `TimeSpan`).

## Global configuration (`Program.cs`)

Require PAR for all clients and set the global lifetime to 5 minutes (300 seconds):

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Require PAR globally
    options.PushedAuthorization.Required = true;

    // Lifetime of a pushed authorization request: 5 minutes, in seconds (int)
    options.PushedAuthorization.Lifetime = 300;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Per-client override for `banking_app`

A client can override the global lifetime with `PushedAuthorizationLifetime` (also seconds, `int`). Here `banking_app` gets 15 minutes (900 seconds):

```csharp
new Duende.IdentityServer.Models.Client
{
    ClientId = "banking_app",
    AllowedGrantTypes = Duende.IdentityServer.Models.GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Duende.IdentityServer.Models.Secret("banking_secret".Sha256()) },
    RedirectUris = { "https://banking.example.com/callback" },
    AllowedScopes = { "openid", "profile", "api1" },

    // Require PAR for this client (redundant if global Required = true, but explicit)
    RequirePushedAuthorization = true,

    // Override the global 300s lifetime with 15 minutes = 900 seconds
    PushedAuthorizationLifetime = 900
}
```

## What PAR does and why lifetime matters

PAR moves the authorization request parameters out of the **front channel** (the browser redirect URL) and into a direct back-channel **HTTP POST** to the pushed authorization endpoint. IdentityServer returns a `request_uri` handle that the browser uses instead of the full parameter set. This:

- prevents leakage of parameters (PII in scopes/claims) through the URL,
- prevents tampering (e.g. an attacker altering the requested scope),
- keeps redirect URLs short, and
- is required by the FAPI 2.0 Security Profile.

The **lifetime** bounds how long the pushed request handle remains valid before the user must complete the authorization. The default is 600 seconds (10 minutes). If your users may need longer (MFA, consent screens), raise it; too short a lifetime causes failures mid-login.

## Edition and version requirement

PAR requires the **Business or Enterprise edition** of Duende IdentityServer and **version 7.0 or later**. Your project (IdentityServer 8.0) supports it. In the **Starter** edition PAR requests are rejected; there you would instead disable the endpoint via `options.Endpoints.EnablePushedAuthorizationEndpoint = false` so discovery reflects that.
