# IdentityServer Hosting Pattern Recommendations

## Recommendation: Use a Separate Dedicated Host

**Do not co-host IdentityServer with your main API.** IdentityServer should be in its own dedicated application to minimize the attack surface.

### Why Co-Hosting with an API Is Problematic

| Hosting Pattern | Pros | Cons |
|----------------|------|------|
| **Separate host (recommended)** | Minimal attack surface, independent scaling, clear security boundary | Additional deployment artifact |
| **Shared with web app** | Fewer projects | Larger attack surface, coupled deployments |
| **Shared with API** | Fewer projects | Security risk, conflicting middleware needs |

Co-hosting with an API increases the attack surface and creates conflicting middleware needs:

1. **Increased attack surface** — Any vulnerability in your API code now has access to the IdentityServer signing keys, session data, and user credentials.
2. **Conflicting middleware** — IdentityServer and your API may need different authentication schemes, CORS policies, and middleware pipelines. These can conflict in subtle ways.
3. **Coupled deployments** — API changes force redeployment of your identity provider, and vice versa.
4. **Scaling** — You cannot scale the API and IdentityServer independently.

## IssuerUri: Infer from Request URL by Default

**Do not set `IssuerUri` explicitly unless you have a specific need.** By default, IdentityServer infers the issuer from the incoming request URL. This is the recommended behavior.

```csharp
builder.Services.AddIdentityServer(options =>
{
    // ❌ Don't set this unless you have a specific reason:
    // options.IssuerUri = "https://identity.mycompany.com";
    
    // ✅ Let it be inferred from the request URL (default behavior)
});
```

Setting `IssuerUri` manually is only needed when IdentityServer is accessed on a different address than the expected issuer. For example, in a Kubernetes cluster where the internal address (e.g., `http://identity-svc:5000`) differs from the external URL (e.g., `https://identity.mycompany.com`). In that case, you'd set the external URL as the issuer so tokens match what clients expect.

If you set `IssuerUri` manually, all clients must know this exact value. Mismatches cause token validation failures.
