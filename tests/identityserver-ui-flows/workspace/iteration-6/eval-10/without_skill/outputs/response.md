# Tenant via acr_values

## Reading it
IdentityServer parses `acr_values` for you. In the login page:

```csharp
var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
string? tenant = context?.Tenant;      // from acr_values "tenant:acme"
```
`context.Tenant` is the value after `tenant:`; `context.AcrValues` has the full list (including `idp:` entries).

## Storing it in the session
Add a claim and/or auth property at sign-in:

```csharp
var user = new IdentityServerUser(subjectId)
{
    DisplayName = username,
    AdditionalClaims = { new Claim("tenant", tenant ?? "") }
};
var props = new AuthenticationProperties();
props.Items["tenant"] = tenant;
await HttpContext.SignInAsync(user, props);
```
Show branding with `tenant` in the view (`ViewData["Tenant"]`), choosing CSS/logo from a whitelist (never trust raw input in paths).

## Forcing re-login if tenant switches
The authorize endpoint doesn't know about tenants, so the login page isn't shown if there's an existing session. Use a custom `ICustomAuthorizeRequestValidator` or `IAuthorizeInteractionResponseGenerator`:

```csharp
public class TenantInteraction : AuthorizeInteractionResponseGenerator
{
    public TenantInteraction(...) : base(...) { }

    public override async Task<InteractionResponse> ProcessInteractionAsync(ValidatedAuthorizeRequest request, ConsentResponse? consent = null)
    {
        var response = await base.ProcessInteractionAsync(request, consent);
        if (response.IsLogin || response.IsError) return response;

        var requested = request.GetTenant();
        var current = request.Subject.FindFirst("tenant")?.Value;
        if (requested != null && !string.Equals(requested, current, StringComparison.OrdinalIgnoreCase))
            return new InteractionResponse { IsLogin = true };
        return response;
    }
}
builder.Services.AddIdentityServer().AddAuthorizeInteractionResponseGenerator<TenantInteraction>();
```
Alternative: a simpler approach is to have the client send `prompt=login` when switching. After re-login on the page, the old session is replaced via a fresh `SignInAsync`.
