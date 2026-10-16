# Tenant-specific branding in a Spaces deployment

## Which space is this request for?
Spaces resolve the space **on the server** at the start of each request (from origin and/or path, validated against configured match patterns). Login, consent, logout and error pages are shared and run inside the resolved space, but there is **no built-in per-space branding**. Inject `ISpaceContextAccessor` into your UI services, read the space ID, and load your own settings:

```csharp
public interface IBrandingService { Task<Branding> GetAsync(CancellationToken ct); }

public class BrandingService(ISpaceContextAccessor spaces, IBrandingStore store) : IBrandingService
{
    public Task<Branding> GetAsync(CancellationToken ct)
        => store.FindAsync(spaces.GetSpaceId(), ct)   // fall back to default branding if null
           ?? Task.FromResult(Branding.Default);
}

// Login.cshtml.cs
public class LoginModel(IBrandingService branding) : PageModel
{
    public Branding Branding { get; private set; } = Branding.Default;
    public async Task OnGetAsync(string returnUrl) => Branding = await branding.GetAsync(HttpContext.RequestAborted);
}
```
`ISpaceContextAccessor` is usable in middleware placed after `UseSpaceResolution()`:
```csharp
app.UseForwardedHeaders();
app.UseSpaceResolution();
app.UseRouting();
app.UseIdentityServer();
```

## Should you read the `acr_values` tenant hint?
**Don't use it to determine the space.** `acr_values=tenant:x` is an **untrusted, client-supplied** hint. A client cannot select a space with it; the space is chosen by the server from the request URL (client authority = the space's base URL, e.g. `https://login.example.com/t/acme`). Prefer `ISpaceContextAccessor` whenever the space already identifies the tenant.

The hint remains useful **inside** a space for sub-tenants (e.g. several brands within Acme); treat it as a hint, validate it, and fall back to the space's default branding.

Also make sure forwarded headers only come from `KnownProxies`, since an untrusted forwarded host could cause the wrong space (and branding) to resolve.
