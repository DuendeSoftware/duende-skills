# Skipping the login page with a Google hint

## Client side: send `acr_values=idp:Google`
ASP.NET Core / BFF:
```csharp
options.Events.OnRedirectToIdentityProvider = ctx =>
{
    ctx.ProtocolMessage.AcrValues = "idp:Google";
    return Task.CompletedTask;
};
```
SPA (oidc-client-ts): `userManager.signinRedirect({ extraQueryParams: { acr_values: "idp:Google" } })` (or the library's `acr_values` option). Hints combine, space-separated: `idp:Google tenant:acme`.

IdentityServer parses it into `AuthorizationRequest.IdP` and removes it from `AcrValues`.

## What the login page must do
IdentityServer itself does **not** redirect or verify the scheme — the login page does:

```csharp
public async Task<IActionResult> OnGet(string? returnUrl)
{
    var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

    if (context?.IdP is { } idp && idp != IdentityServerConstants.LocalIdentityProvider)
    {
        // verify the scheme exists (static or dynamic provider)
        if (await _schemes.GetSchemeAsync(idp) != null)
            return RedirectToPage("/ExternalLogin/Challenge", new { scheme = idp, returnUrl });
    }
    // no/invalid hint -> normal login UI
    ...
}
```
The challenge page then stores `scheme` and `returnUrl` in `AuthenticationProperties.Items`, with `RedirectUri` at the callback page. The callback reads the external cookie, finds/provisions the local user, calls `SignInAsync(new IdentityServerUser(sub) { IdentityProvider = "Google" })`, signs out the external cookie, validates and redirects to `returnUrl`.

## Gotchas
- If the client has `IdentityProviderRestrictions` and Google isn't in them, the hint is silently dropped (`context.IdP` is null). Make sure `spa.app` allows it (or has no restrictions), e.g. `IdentityProviderRestrictions = { "Google" }`.
- If the existing session came from a different IdP, the login page is shown again.
- `idp:local` is reserved: show only the local login form.
- The user may still see Google's own sign-in if they have no Google session.
