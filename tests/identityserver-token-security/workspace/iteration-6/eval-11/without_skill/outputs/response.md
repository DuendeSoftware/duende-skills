# JAR `request_uri` support: risks and safe configuration

With `request_uri`, the client passes a URL; IdentityServer fetches the request object from it.

## Risks
- **SSRF**: the server makes outbound HTTP calls to attacker-influenced URLs (internal services, cloud metadata `169.254.169.254`).
- **DoS**: slow or huge responses tie up resources; repeated fetches are amplification.
- **Replay/TOCTOU**: content at the URL can change between fetches; request objects reused.
- **Information leakage** via redirects, and unauthenticated URLs hosting sensitive data.
- **Open fetch from any host** if not restricted.

## Safe configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Endpoints.EnableJwtRequestUri = true;      // off by default
    options.AllowedJwtAlgorithms = ["PS256", "ES256"];
})
.AddInMemoryClients(Config.Clients)
.AddJwtRequestUriHttpClient(c => c.Timeout = TimeSpan.FromSeconds(5));
```

Per client:
```csharp
new Client
{
    ClientId = "partner_app",
    RequireRequestObject = true,
    RequestUris = { "https://partner.example.com/requests/" }, // allow-list
    ClientSecrets = { new Secret { Type = SecretTypes.JsonWebKey, Value = jwk } }
}
```

Mitigations:
- Require HTTPS and an allow-list of request URIs per client; block private/link-local IPs and disable redirects.
- Short timeouts and size limits on the HttpClient.
- Require signed request objects, with `exp`, `aud`, `jti` validation.
- Prefer **PAR** instead: the request is pushed directly to IdentityServer over an authenticated back channel, with no outbound fetches.
- Log and monitor fetch failures.
