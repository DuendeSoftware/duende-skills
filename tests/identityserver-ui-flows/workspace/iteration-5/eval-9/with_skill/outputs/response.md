# Consent Configuration: Required vs. Optional Scopes, Revocation, and M2M

## 1. Make `profile` mandatory

`IdentityResource` and `ApiScope` both expose a `Required` bool. Setting `Required = true` means the user **cannot decline** the scope: if the consent response omits it, IdentityServer returns `access_denied` and the whole authorization request **fails**.

```csharp
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(),
    new IdentityResources.Profile { Required = true }, // must be granted or the flow fails
    new IdentityResources.Email()
})
```

> Behavior: if the user unchecks `profile` on the consent screen, the consent response omits it, IdentityServer treats that as `access_denied`, and the request does not complete.

## 2. Make `marketing` optional

Add a `marketing` `ApiScope` with `Required = false`. Optional scopes can be declined; the flow still **succeeds** — the issued tokens/userinfo simply omit that scope's data.

```csharp
.AddInMemoryApiScopes(new List<ApiScope>
{
    new ApiScope("api1", "My API"),
    new ApiScope("marketing", "Marketing preferences") { Required = false } // declinable
})
```

Add it to the client's `AllowedScopes` so it can be requested:

```csharp
AllowedScopes = { "openid", "profile", "email", "api1", "marketing" }
```

> Behavior: the user can uncheck `marketing`; consent still succeeds and access is granted for everything else.

## 3. Admin/support endpoint to revoke remembered consent

Use `IIdentityServerInteractionService.RevokeUserConsentAsync(clientId)`. This removes **all** persisted grants for the current user/client pair — remembered consent, reference tokens, and refresh tokens.

```csharp
public class RevokeConsentModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public RevokeConsentModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public async Task<IActionResult> OnPost()
    {
        // Revoke the current user's remembered consent + persisted grants for web.app
        await _interaction.RevokeUserConsentAsync("web.app");
        return RedirectToPage();
    }
}
```

> `RevokeUserConsentAsync` operates on the **currently signed-in user**. To revoke on behalf of an arbitrary user from an admin console, use the persisted-grant store (`IPersistedGrantStore` / `IPersistedGrantService.RemoveAllGrantsAsync(subjectId, clientId)`) instead.

## 4. Does the M2M (client credentials) client show a consent prompt?

**No.** Consent applies **only to user-based (interactive) authorization requests**. The client-credentials grant has no end user present, so IdentityServer **never** shows a consent prompt for it. Access for an M2M client is governed solely by its `AllowedScopes` — whatever scopes are listed there are what the client can request and receive. `RequireConsent` is irrelevant for client-credentials flows.

## Summary

| Requirement | Configuration | Result |
| ----------- | ------------- | ------ |
| `profile` mandatory | `IdentityResources.Profile { Required = true }` | Declining → `access_denied`, request fails |
| `marketing` optional | `new ApiScope("marketing") { Required = false }` | Declining still succeeds; scope data omitted |
| Revoke remembered consent | `RevokeUserConsentAsync("web.app")` | Clears remembered consent + reference/refresh tokens |
| M2M consent | N/A | Never prompted; `AllowedScopes` alone governs access |
