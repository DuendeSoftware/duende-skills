# IdentityServer Hosting Pattern and IssuerUri Guidance

## Hosting Pattern: Use a Separate Dedicated Host

**Do not co-host IdentityServer with your API.** IdentityServer should run in its own dedicated application.

### Why Separate Hosting Is Recommended

| Hosting Pattern | Pros | Cons |
|----------------|------|------|
| **Separate host (recommended)** | Minimal attack surface, independent scaling, clear security boundary | Additional deployment artifact |
| **Shared with API** | Fewer projects | Security risk, conflicting middleware needs |

Co-hosting with an API increases the attack surface in several ways:

1. **Larger attack surface** — Any vulnerability in your API code could potentially be exploited to compromise the identity system
2. **Conflicting middleware needs** — APIs typically need different authentication, authorization, CORS, and error handling middleware than the IdentityServer endpoints and UI pages
3. **Coupled deployments** — API changes force IdentityServer redeployment, increasing risk to the identity system
4. **Scaling conflicts** — APIs and identity endpoints have different traffic patterns and resource needs

While it is technically possible to co-host (IdentityServer is just ASP.NET Core middleware), the security implications make it a poor choice for production systems.

### Recommended Architecture

```
┌─────────────────┐     ┌─────────────────┐
│  IdentityServer │     │   Your API      │
│  (dedicated)    │     │   (separate)    │
│                 │     │                 │
│  - Login UI     │     │  - API endpoints│
│  - Token issuer │     │  - JWT Bearer   │
│  - Discovery    │     │    validation   │
└─────────────────┘     └─────────────────┘
```

## IssuerUri: Let It Be Inferred

**Do not set `IssuerUri` explicitly** unless you have a specific need. Let IdentityServer infer it from the incoming request URL.

### Why Inference Is Better

By default, IdentityServer derives the issuer from the request URL (scheme + host). This means:
- The issuer in discovery matches the URL clients use to reach IdentityServer
- No configuration drift between environments
- Works correctly with ForwardedHeaders behind proxies

### When to Set It Manually

Set `IssuerUri` explicitly **only** when IdentityServer is accessed on a different address than the expected issuer. Common scenarios:

- **Internal Kubernetes address**: IdentityServer listens on `http://identityserver-svc:80` internally, but clients know it as `https://identity.example.com`
- **Multiple environments sharing tokens**: If tokens issued in one environment must be valid in another

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Only set when the internal address differs from the public address
    options.IssuerUri = "https://identity.example.com";
});
```

**Warning**: If you set `IssuerUri` manually, all clients must use this exact value. A mismatch between the issuer in tokens and the issuer clients expect will cause validation failures.
