# JAR `request_uri`: risks and safe configuration

## Why it's off by default
`request_uri` support is disabled by default (`options.Endpoints.EnableJwtRequestUri`). Anyone who knows a client ID can make IdentityServer fetch a URL of their choosing before the user signs in: **Server-Side Request Forgery (SSRF)** (RFC 9101 §10.4).

Risks:
- Requests to internal hosts, loopback, private ranges, cloud metadata (e.g. `169.254.169.254`).
- Error responses reveal whether hosts/ports exist on your network (internal reconnaissance).
- Redirects and DNS rebinding bypass naive URL checks.
- Slow/large responses (DoS); retries amplify abuse.

**Prefer PAR**: IdentityServer never fetches a caller-supplied URL.

## If you still enable it

```csharp
using idunno.Security;

builder.Services.AddIdentityServer(options =>
{
    options.Endpoints.EnableJwtRequestUri = true;
})
.AddInMemoryClients(Config.Clients)
.AddJwtRequestUriHttpClient(client =>
{
    client.Timeout = TimeSpan.FromSeconds(5);            // default 10s
    client.MaxResponseContentBufferSize = 64 * 1024;     // request objects are small
})
.ConfigurePrimaryHttpMessageHandler(() => SsrfSocketsHttpHandlerFactory.Create()); // idunno.Security.Ssrf

// Client: require signed objects
new Client
{
    ClientId = "partner_app",
    RequireRequestObject = true,
    ClientSecrets = { new Secret { Type = IdentityServerConstants.SecretTypes.JsonWebKey, Value = "<public JWK>" } }
}
```

Safeguards:
- Use a handler that validates the IP **at connection time** (`idunno.Security.Ssrf`: blocks loopback/private/link-local, https only, no redirects, no proxy). A `DelegatingHandler` that only checks the URL is **not** enough (`localhost` names, redirects, DNS rebinding).
- **No retries** on this HTTP client (the caller controls the URL); exclude it from global retry policies like Aspire service defaults.
- HTTPS only (RFC 9101 §5.2).
- Restrict egress from IdentityServer hosts with network rules, and protect cloud metadata endpoints (e.g. require IMDSv2 on AWS).
- Request objects must be signed with a key registered on the client, so content is tamperproof.
