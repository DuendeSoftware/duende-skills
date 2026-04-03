# IdentityServer Hosting Pattern and IssuerUri

## Hosting Pattern: Separate Dedicated Host

**Recommendation: Use a separate, dedicated host for IdentityServer** rather than co-hosting with your API.

### Why Not Co-Host?

| Hosting Pattern | Pros | Cons |
|---|---|---|
| **Separate host (recommended)** | Minimal attack surface, independent scaling, clear security boundary | Additional deployment artifact |
| **Shared with API** | Fewer projects | Security risk, conflicting middleware needs |

Co-hosting IdentityServer with an API:
- **Increases the attack surface** — any vulnerability in the API exposes the identity system
- **Creates conflicting middleware needs** — IdentityServer and APIs have different authentication/authorization requirements
- **Couples deployments** — you can't update or scale them independently
- **Blurs security boundaries** — the identity provider should be the most protected component

## IssuerUri Configuration

**Recommendation: Do NOT explicitly set `IssuerUri`.** Let IdentityServer infer it from the request URL by default.

```csharp
builder.Services.AddIdentityServer(options =>
{
    // IssuerUri: Not recommended to set; inferred from request URL by default.
    // options.IssuerUri = "https://identity.example.com"; // DON'T do this unless needed
});
```

### When to Set IssuerUri Manually

Only set `IssuerUri` when IdentityServer is accessed on a **different address** than the expected issuer. For example:
- Internal Kubernetes addresses (pod-to-pod uses `http://identity-service:8080` but external issuer should be `https://identity.example.com`)
- Port mapping scenarios where the internal and external URLs differ

When you set `IssuerUri` manually, clients must know this exact value. Inferring from request URLs is more flexible and avoids configuration mismatches.
