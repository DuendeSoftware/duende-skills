# Consent configuration

## Mandatory vs optional scopes
`IdentityResource.Required` / `ApiScope.Required` mark a scope as mandatory: the consent UI should show it checked & disabled and always include it. `Emphasize` just highlights it.

```csharp
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(),
    new IdentityResources.Profile { Required = true },
    new IdentityResources.Email()
})
.AddInMemoryApiScopes(new List<ApiScope>
{
    new ApiScope("api1", "My API"),
    new ApiScope("marketing", "Marketing emails") { Required = false, Emphasize = false }
})
```
Add "marketing" to `web.app`'s `AllowedScopes`. 

Consent page: render required scopes as disabled checked checkboxes (and post them via a hidden field), optional ones as editable checkboxes. On POST, validate server-side that all required scopes are present; if not, don't grant – call `DenyAuthorizationAsync(request, AuthorizationError.AccessDenied)` or re-display with an error:

```csharp
var required = request.ValidatedResources.Resources.IdentityResources.Where(r => r.Required).Select(r => r.Name)
    .Concat(request.ValidatedResources.Resources.ApiScopes.Where(s => s.Required).Select(s => s.Name));
if (required.Except(ScopesConsented).Any()) { ModelState.AddModelError("", "Required scopes must be accepted"); return Page(); }
await _interaction.GrantConsentAsync(request, new ConsentResponse { ScopesValuesConsented = ScopesConsented, RememberConsent = true });
```

## "My consents" – revoke
```csharp
public class GrantsModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public GrantsModel(IIdentityServerInteractionService i) => _interaction = i;

    [Authorize]
    public async Task<IActionResult> OnPostRevokeAsync()
    {
        await _interaction.RevokeUserConsentAsync("web.app");
        return RedirectToPage();
    }
}
```
`RevokeUserConsentAsync(clientId)` revokes consent for the current user (the subject is taken from the signed-in user). `GetAllUserGrantsAsync()` lists grants. Use `RevokeTokensForCurrentSessionAsync()` to also revoke tokens. The endpoint must require authentication and use anti-forgery (POST).

## Client credentials
No consent. There's no user, no interactive flow; consent applies only to interactive flows (code, implicit, hybrid) with `RequireConsent = true`. The client is trusted via its secret.
