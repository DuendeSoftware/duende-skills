# Skipping the login page with a Google hint

## Client side
Send an IdP hint using `acr_values=idp:Google`.

```csharp
.AddOpenIdConnect("oidc", o =>
{
    o.Events.OnRedirectToIdentityProvider = ctx =>
    {
        if (ctx.Properties.Items.TryGetValue("idp", out var idp))
            ctx.ProtocolMessage.AcrValues = $"idp:{idp}";
        return Task.CompletedTask;
    };
});
```
For a SPA with oidc-client-ts: `userManager.signinRedirect({ extraQueryParams: { acr_values: "idp:Google" } })`.

## What the login page must do
1. Get the context: `var ctx = await _interaction.GetAuthorizationContextAsync(returnUrl);`
2. IdentityServer parses `idp:` into `ctx.IdP`.
3. If `ctx.IdP` is set, is a registered scheme, and allowed for the client (`IdentityProviderRestrictions`), immediately redirect to your challenge endpoint:
```csharp
if (ctx?.IdP != null && schemeKnown && (restrictions.Count == 0 || restrictions.Contains(ctx.IdP)))
    return RedirectToPage("/ExternalLogin/Challenge", new { scheme = ctx.IdP, returnUrl });
```
4. Challenge Google with `RedirectUri` = callback and `returnUrl` stored in properties; the callback signs in locally with `IdentityProvider = "Google"`, deletes the external cookie, and redirects to `returnUrl`.
5. If the hint is unknown/disallowed, fall back to the normal login UI.

Also make sure the SPA client has no `IdentityProviderRestrictions` that exclude Google. Note that the hint only skips UI; if the user has no Google session, Google will show its own login.
