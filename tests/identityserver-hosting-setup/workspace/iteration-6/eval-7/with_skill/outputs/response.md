# Hosting pattern and IssuerUri

## Hosting: use a separate, dedicated host
Don't co-host IdentityServer with your API. It's technically possible, but not recommended.

| Pattern | Pros | Cons |
|---|---|---|
| **Separate host (recommended)** | Minimal attack surface, independent scaling, clear security boundary | Extra deployment artifact |
| Shared with web app | Fewer projects | Larger attack surface, coupled deployments |
| Shared with API | Fewer projects | Security risk, conflicting middleware needs |

The deployment-complexity saving is small versus the risk: IdentityServer holds signing keys, sessions and grants, and the API's authentication/middleware needs conflict with it. Containers/Aspire/compose make a second deployable cheap. Start with the template: `dotnet new install Duende.Templates` then `dotnet new duende-is-empty -n IdentityServer`.

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapDefaultControllerRoute();
app.Run();
```

## IssuerUri: let it be inferred
Setting it is not recommended. It's inferred from the request URL (lowercased by default via `LowerCaseIssuerUri`). Set it only if IdentityServer is accessed at a different address than the expected issuer (e.g. internal Kubernetes address). A manual value must be known exactly by all clients; mismatches cause token validation failures. Behind a proxy, correct the scheme/host with forwarded headers (`UseForwardedHeaders()` before `UseIdentityServer()`) instead.
