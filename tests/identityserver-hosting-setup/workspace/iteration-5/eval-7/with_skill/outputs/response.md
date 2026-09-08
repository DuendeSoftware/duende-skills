# Hosting Pattern and IssuerUri Recommendation

## Use a separate, dedicated host — don't co-host with your API

I'd advise **against** co-hosting IdentityServer with your main API, even though it means one fewer deployment artifact. IdentityServer should run in its **own dedicated application** to keep the security boundary clear and the attack surface minimal.

Why co-hosting with an API is a poor trade-off:

- **Larger attack surface** — IdentityServer holds signing keys and issues tokens; bundling it with general-purpose API code means any vulnerability in the API now sits in the same process as your token issuer.
- **Conflicting middleware needs** — IdentityServer and an API have different pipeline requirements (authentication schemes, CORS, cookie vs. bearer handling, UI/static-file needs). Sharing one pipeline forces awkward compromises and easy misconfiguration.
- **Coupled deployments and scaling** — you can no longer deploy, patch, or scale the identity provider independently of the API.

| Hosting Pattern | Pros | Cons |
| --- | --- | --- |
| **Separate host (recommended)** | Minimal attack surface, independent scaling, clear security boundary | One extra deployment artifact |
| Shared with web app | Fewer projects | Larger attack surface, coupled deployments |
| Shared with API | Fewer projects | Security risk, conflicting middleware needs |

The "reduce deployment complexity" goal is better served with your existing CI/CD and orchestration (containers/Kubernetes) than by collapsing the security boundary.

## IssuerUri: let it be inferred — don't set it explicitly

**Do not set `IssuerUri` explicitly** by default. Leave it unset and let IdentityServer **infer the issuer from the request URL**. This "just works" and avoids issuer-mismatch bugs (where clients validate `iss` against a value that no longer matches how they reach the server).

Set `IssuerUri` manually **only** when IdentityServer is accessed on a **different address than the expected public issuer** — for example, when it's reached over an internal Kubernetes service address but must present a stable public issuer to clients. In that specific case a fixed `IssuerUri` is warranted; otherwise inference is the safer choice.

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Leave IssuerUri unset — inferred from the request URL by default.
    // options.IssuerUri = "https://identity.example.com"; // only for special cases
});
```
