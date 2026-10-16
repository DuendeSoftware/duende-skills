# Which tenant is this request for? Branding on the login page

**Determine the tenant from the request's routing context, not from client-supplied parameters.** In a path-based deployment (`/t/acme/...`) or host-based one, the tenant is encoded in the URL that reached the login page. Read it from the request path/path base, or from whatever tenant-context service the Spaces library exposes (check its docs; I can't name the exact type reliably).

```csharp
public class LoginModel : PageModel
{
    private readonly ITenantContext _tenant; // hypothetical: provided by your multi-tenant layer
    public LoginModel(ITenantContext tenant) => _tenant = tenant;

    public string Branding { get; private set; } = "default";

    public void OnGet(string returnUrl)
    {
        Branding = _tenant.Name; // e.g. "acme" -> choose CSS/logo
    }
}
```

Without such a service, parse `HttpContext.Request.PathBase` / `Host`.

**Should you read `acr_values` `tenant:xyz`?** `acr_values` with `tenant:` is a legacy IdentityServer convention for passing tenant hints, readable via `interaction.GetAuthorizationContextAsync(returnUrl)` → `context.Tenant`. It is a client-supplied hint, so:
- It can be spoofed or mismatched with the URL's tenant.
- With Spaces, the URL already identifies the tenant authoritatively, so prefer that.
- Use `acr_values` only as fallback (e.g. a shared login host) and validate it against the tenant the client belongs to.

For branding: key off the resolved tenant, load logo/colors from a per-tenant config, and fall back to default branding for unknown values. Also verify `returnUrl` belongs to the same tenant to avoid cross-tenant branding confusion.
