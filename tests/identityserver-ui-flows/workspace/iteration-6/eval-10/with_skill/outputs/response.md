# Tenant branding via `acr_values=tenant:acme`

## Reading it
IdentityServer parses the well-known `tenant:` acr value for you and removes it from `AcrValues`:

```csharp
var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
var tenant = context?.Tenant;     // "acme", or null if not requested
```
Treat it as an **untrusted hint**: use it for branding (pick a theme from an allow-list, never build file paths from it), scoping user lookup, or HRD; always verify the signed-in user actually belongs to that tenant.

(Clients send it e.g. from the OIDC handler: `ctx.ProtocolMessage.AcrValues = "tenant:acme";`, and it can be combined: `idp:Google tenant:acme`.)

## Storing it in the session
```csharp
var isuser = new IdentityServerUser(user.SubjectId)
{
    DisplayName = user.Username,
    Tenant = tenant            // issues the `tenant` session claim
};
await HttpContext.SignInAsync(isuser);
```
This puts the `tenant` claim in the session cookie only. To get it in tokens, emit it from your profile service (and add it to the relevant scope/resource claims).

## Forcing re-login on tenant switch
By default, a signed-in user is reused even if a different tenant is requested. Turn on:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ValidateTenantOnAuthorization = true;
});
```
The login page is then shown again whenever the requested tenant differs from the session's `tenant` claim (or the session has none). On that login, `Tenant = tenant` is set on the new `SignInAsync`, replacing the old session.

## Login page branding sketch
```csharp
public async Task<IActionResult> OnGet(string? returnUrl)
{
    ReturnUrl = returnUrl;
    var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
    Tenant = context?.Tenant;
    Theme = KnownTenants.TryGetValue(Tenant ?? "", out var t) ? t : DefaultTheme;   // allow-list
    return Page();
}

// on POST: verify membership, don't trust the hint
if (!await _tenantService.IsMemberAsync(user.SubjectId, Tenant)) { ModelState.AddModelError("", "Not a member of this tenant"); return Page(); }
```

## Caveats
- The tenant hint is **not** Spaces. Spaces give real isolation (data, issuers) and are chosen by the server from origin/path, never via `acr_values`.
- `Tenant` is not processed at the token endpoint.
