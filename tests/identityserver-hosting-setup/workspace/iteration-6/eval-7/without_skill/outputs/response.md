# Hosting pattern and IssuerUri

**Recommendation:** host IdentityServer as its own separate ASP.NET Core application rather than co-hosting with the API. Reasons: independent scaling and deployment, a different security boundary (it holds signing keys, user data and sessions), different lifecycle/availability needs, and avoiding middleware/auth-scheme conflicts with the API. Co-hosting is technically possible (just add `AddIdentityServer` and `UseIdentityServer` to the API), and acceptable for small/simple setups, but it couples concerns and makes it harder to split later. If you do co-host, keep the IdentityServer code in clearly separated areas and keep API auth using JWT bearer against your own authority.

**IssuerUri:** let it be inferred from the request host (Duende default) in general. Setting it explicitly is only needed when the public URL differs from what the server sees (behind proxies, multiple hostnames), and then prefer correct forwarded headers over hardcoding. Explicit values can hide misconfiguration and must match what clients/APIs validate. If you set one, use a stable https URL with no trailing slash issues.

```csharp
builder.Services.AddIdentityServer();
var app = builder.Build();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
```
