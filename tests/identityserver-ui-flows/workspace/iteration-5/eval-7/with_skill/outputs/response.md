# Fixing OIDC State URL-Length and Lost returnUrl

Two separate issues:

1. **URL too long** — the external OIDC handler serializes its protocol state (including the correlation/return data) into the `state` parameter carried in the URL. With `corporate-idp` this pushes past browser/proxy URL limits.
2. **returnUrl lost** — the original authorize `returnUrl` isn't being carried through the challenge → external round-trip → callback, so users land on the home page.

## Fix 1 — Store OIDC state server-side

IdentityServer ships an `IDistributedCache`-backed state formatter. Register it for the `corporate-idp` scheme so the state lives in the cache and only a short key travels in the URL.

```csharp
// Program.cs
builder.Services.AddIdentityServer(/* ... */);

builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", "Corporate IdP", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://corp.example.com";
        options.ClientId = "identityserver";
        // ...
    });

// Move OIDC state off the URL and into IDistributedCache for this scheme
builder.Services.AddOidcStateDataFormatterCache("corporate-idp");
```

> Register a distributed cache (`AddDistributedMemoryCache()` for dev, Redis/SQL for production). `AddOidcStateDataFormatterCache()` with no arguments applies to all OIDC handlers; passing `"corporate-idp"` scopes it to just that scheme.

## Fix 2 — Preserve returnUrl across the whole flow

Put the `returnUrl` in `AuthenticationProperties.Items` on the challenge, then read it back from `result.Properties.Items` in the callback.

### Challenge (external login trigger)

```csharp
public IActionResult OnGetExternal(string scheme, string? returnUrl)
{
    var props = new AuthenticationProperties
    {
        RedirectUri = Url.Page("/Account/ExternalLogin", "Callback"),
        Items =
        {
            { "scheme", scheme },        // "corporate-idp"
            { "returnUrl", returnUrl }   // <-- preserved here
        }
    };

    return Challenge(props, scheme);
}
```

### Callback

```csharp
public async Task<IActionResult> OnGetCallback()
{
    // Read the external identity from the external cookie
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        throw new InvalidOperationException("External authentication error");

    // Recover the returnUrl that was stashed before the challenge
    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
    var scheme = result.Properties.Items["scheme"];

    // Provision / find local user and establish the session
    var user = FindOrProvisionUser(scheme, result.Principal!);
    await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId)
    {
        IdentityProvider = scheme
    });

    // Clean up the temporary external cookie
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    // Validate before redirecting — prevents open redirect
    if (Url.IsLocalUrl(returnUrl) || await _interaction.IsValidReturnUrl(returnUrl))
    {
        return Redirect(returnUrl);
    }
    return Redirect("~/");
}
```

## Why this works

| Problem | Root cause | Fix |
| ------- | ---------- | --- |
| URL too long | OIDC `state` serialized into the query string | `AddOidcStateDataFormatterCache("corporate-idp")` stores state in `IDistributedCache`; only a lookup key is in the URL |
| returnUrl lost | Not persisted across the challenge/callback | Store in `AuthenticationProperties.Items` on `Challenge`; read from `result.Properties.Items` on callback |
| Open redirect risk | Redirecting to an unvalidated returnUrl | Validate with `Url.IsLocalUrl` / `_interaction.IsValidReturnUrl` before `Redirect` |

The two fixes are independent but complementary: caching the state keeps the URL short, and using `AuthenticationProperties.Items` keeps `returnUrl` intact regardless of how the state is stored.
