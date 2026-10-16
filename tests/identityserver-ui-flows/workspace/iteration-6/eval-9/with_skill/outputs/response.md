# Consent configuration

## When consent applies
Consent applies **only to interactive, user-based authorization requests**. Your machine-to-machine client using **client credentials never shows a consent prompt** — there is no user; `Client.AllowedScopes` alone governs access. `RequireConsent` (default `false`) matters only for interactive clients: `web.app` has `true`; `spa.app` has `false`.

## Required vs optional scopes
`IdentityResource` and `ApiScope` have `Required`:
- Required scope missing from the consent response → IdentityServer returns `access_denied` and the flow fails.
- Optional scope declined → flow succeeds; tokens/userinfo just omit that data.

```csharp
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId { Required = true },
    new IdentityResources.Profile { Required = true },   // mandatory – cannot be declined
    new IdentityResources.Email()
})
.AddInMemoryApiScopes(new List<ApiScope>
{
    new ApiScope("api1", "My API"),
    new ApiScope("marketing", "Marketing communications") { Required = false } // optional
})
```
Add `"marketing"` to `web.app`'s `AllowedScopes`. In the consent page render required scopes as locked checked boxes (and post them via hidden fields) and optional ones as normal checkboxes; post only the selected ones in `ScopesValuesConsented`:

```csharp
await _interaction.GrantConsentAsync(context, new ConsentResponse
{
    ScopesValuesConsented = ScopesConsented,
    RememberConsent = true
});
```

## Remembered consent
Controlled via `Client.AllowRememberConsent` and `Client.ConsentLifetime`; stored in the persisted-grant store. Consent is re-prompted if none/expired, a new scope is requested, `offline_access` is requested, parameterized scopes are used, or `AllowRememberConsent = false`. (Device flow consent is never remembered in v8.)

## "My consents" – revoke for `web.app`
```csharp
[Authorize]
public class MyConsentsModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public MyConsentsModel(IIdentityServerInteractionService i) => _interaction = i;

    public async Task<IActionResult> OnPostRevoke()      // POST + anti-forgery (Razor Pages default)
    {
        // revokes for the *current signed-in user* only
        await _interaction.RevokeUserConsentAsync("web.app");
        return RedirectToPage();
    }
}
```
```html
<form method="post" asp-page-handler="Revoke"><button>Revoke access for Web Application</button></form>
```
Caveat: `RevokeUserConsentAsync(clientId)` removes **all** persisted grants for that user/client — remembered consent, reference tokens and refresh tokens — not just the consent record. Next login will prompt again.

## Summary
- Mandatory: `Required = true` (decline ⇒ `access_denied`). Optional: `Required = false`.
- Revoke with `RevokeUserConsentAsync`.
- Client credentials ⇒ no consent.
