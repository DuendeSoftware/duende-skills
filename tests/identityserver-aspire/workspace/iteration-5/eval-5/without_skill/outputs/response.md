`IDX20803: Unable to obtain configuration from '.../.well-known/openid-configuration'` comes from the Microsoft JWT/OIDC middleware: at startup (or first token validation) it tries to download the OpenID Connect discovery document from your authority and the HTTP call fails. In an Aspire solution the usual cause is **timing** — the API boots before IdentityServer is listening, so the metadata request is refused.

## Most likely root cause

Aspire starts resources concurrently. Your API starts, immediately tries to fetch the discovery document from IdentityServer, but IdentityServer isn't accepting requests yet — so the fetch throws and surfaces as IDX20803.

(Worth ruling out secondary causes too: a wrong/misspelled `Authority` URL, or an HTTPS dev-cert trust issue. But if the URL is correct and it only fails on startup, it's an ordering problem.)

## Fix: order the API after IdentityServer in the AppHost

Tell Aspire the API depends on IdentityServer so it starts afterward and knows its address:

```csharp
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server");

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)   // make the IdentityServer endpoint URL available to the API
    .WaitFor(identityServer);        // don't start the API until IdentityServer is up
```

- **`WithReference(identityServer)`** injects IdentityServer's endpoint so the authority resolves to the right runtime URL.
- **`WaitFor(identityServer)`** delays the API's startup until IdentityServer is running, which removes the race condition.

## A more robust option

If you want the middleware to tolerate a briefly-unavailable authority even after ordering, you can also make discovery lazy / retry — e.g. set `options.RequireHttpsMetadata` appropriately for local dev and avoid forcing an eager metadata load — but fixing the startup order in the AppHost is the correct primary solution and usually all you need.
