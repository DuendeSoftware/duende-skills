# Fixing Long OIDC State and Lost returnUrl

There are two independent problems here:

1. The OpenID Connect `state` parameter is serialized into the redirect URL, and for `corporate-idp` it's growing large enough to exceed URL length limits.
2. The `returnUrl` isn't being carried through the challenge/callback round-trip, so users land on the home page after login.

## Fix 1 — Keep the state out of the URL

The ASP.NET Core OpenID Connect handler stores its correlation/state in the `state` query parameter by default via `ISecureDataFormat<AuthenticationProperties>`. When that gets too big, move it to server-side storage and only send a short key in the URL.

Register a distributed cache and swap in a cache-backed secure data format for the handler's `StateDataFormat`:

```csharp
builder.Services.AddDistributedMemoryCache(); // or Redis in production

builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", "Corporate IdP", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://corp.example.com";
        options.ClientId = "identityserver";

        // Store state in the distributed cache instead of the URL, so only a
        // short cache key is round-tripped through the browser.
        options.StateDataFormat = new DistributedCacheSecureDataFormat(/* cache */);
    });
```

where `DistributedCacheSecureDataFormat` is a custom `ISecureDataFormat<AuthenticationProperties>` that persists the serialized properties in `IDistributedCache` and returns a GUID as the protected payload. This keeps the URL small regardless of how much state the provider round-trips.

You can also reduce what goes into `state` by trimming the properties you store, but cache-backed storage is the robust fix for very long URLs.

## Fix 2 — Preserve returnUrl across challenge and callback

Store `returnUrl` in the authentication properties before challenging, and read it back from the authenticate result in the callback.

### Challenge

```csharp
public IActionResult ExternalLogin(string returnUrl)
{
    var props = new AuthenticationProperties
    {
        RedirectUri = Url.Action("Callback"),
        Items =
        {
            { "returnUrl", returnUrl },
            { "scheme", "corporate-idp" }
        }
    };
    return Challenge(props, "corporate-idp");
}
```

### Callback

```csharp
public async Task<IActionResult> Callback()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (result?.Succeeded != true)
        return BadRequest();

    // Recover the returnUrl stored before the challenge
    var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

    var user = FindOrCreateUser(result.Principal);
    await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId)
    {
        IdentityProvider = "corporate-idp"
    });

    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

    // Validate before redirecting to avoid open redirects
    if (Url.IsLocalUrl(returnUrl))
        return Redirect(returnUrl);

    return Redirect("~/");
}
```

## Summary

- Long URLs come from the OIDC `state`. Persist it server-side (distributed cache) and send only a key.
- Carry `returnUrl` in `AuthenticationProperties.Items` on the challenge, and read it from `result.Properties.Items` in the callback.
- Always validate the recovered `returnUrl` (e.g. `Url.IsLocalUrl`) before redirecting.
