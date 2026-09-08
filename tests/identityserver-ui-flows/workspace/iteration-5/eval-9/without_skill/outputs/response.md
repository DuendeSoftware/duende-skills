# Consent Configuration Explained

## 1. Making `profile` mandatory

Identity resources and API scopes have a `Required` flag. Set it to `true` on the `profile` identity resource so the user cannot proceed without granting it:

```csharp
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(),
    new IdentityResources.Profile { Required = true },
    new IdentityResources.Email()
})
```

When a scope is `Required`, it is effectively non-declinable on the consent screen. If the user tries to withhold it, the authorization request is denied and the sign-in does not complete — the user cannot continue to the application without agreeing to it.

## 2. Making `marketing` optional

Declare a `marketing` API scope with `Required = false`. Optional scopes render as an unchecked-able choice the user can decline, and the flow still completes successfully — the resulting tokens simply won't include that scope.

```csharp
.AddInMemoryApiScopes(new List<ApiScope>
{
    new ApiScope("api1", "My API"),
    new ApiScope("marketing", "Marketing") { Required = false }
})
```

Remember to add `marketing` to the client's `AllowedScopes` so it can be requested in the first place.

## 3. Revoking a user's remembered consent

Remembered consent and issued tokens are kept in the persisted grant store. To let an admin revoke everything a user has granted to the `web.app` client, remove that user's grants for the client:

```csharp
public class RevokeModel : PageModel
{
    private readonly IPersistedGrantService _grants;

    public RevokeModel(IPersistedGrantService grants)
    {
        _grants = grants;
    }

    public async Task<IActionResult> OnPostAsync(string subjectId)
    {
        // Remove all persisted grants (consent, refresh/reference tokens) for this user + client
        await _grants.RemoveAllGrantsAsync(subjectId, "web.app");
        return RedirectToPage();
    }
}
```

This clears the remembered consent so the user will be prompted again next time, and also removes any refresh/reference tokens tied to that grant.

## 4. Does the machine-to-machine client prompt for consent?

No. The client credentials grant is a machine-to-machine flow with no interactive user, so there is no browser and no consent screen — consent only makes sense when a human is present to approve access. What the M2M client can access is determined entirely by its `AllowedScopes`; there is nothing to consent to.

## Summary

| Item | Setting | Effect |
| ---- | ------- | ------ |
| `profile` required | `Required = true` | Cannot be declined; declining fails the request |
| `marketing` optional | `Required = false` | Can be declined; flow still succeeds |
| Revoke consent | `RemoveAllGrantsAsync(subjectId, "web.app")` | Clears remembered consent + tokens |
| M2M consent | none | Client credentials never prompts; `AllowedScopes` governs |
