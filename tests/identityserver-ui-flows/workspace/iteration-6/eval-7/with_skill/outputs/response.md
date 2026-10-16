# Long `state` and lost `returnUrl` for 'corporate-idp'

## 1. State too long → server-side state
The OIDC handler serialises the whole `AuthenticationProperties` into `state` in the URL. Use the IdentityServer `IDistributedCache`-backed data format so only a short key goes on the wire.

```csharp
builder.Services.AddDistributedMemoryCache();   // use Redis / SQL Server when load-balanced

builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", "Corporate IdP", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.SignOutScheme = IdentityServerConstants.SignoutScheme;
        // authority, client id, secret, ResponseType = "code" ...
    });

// only this scheme (or call with no args for all OIDC handlers)
builder.Services.AddOidcStateDataFormatterCache("corporate-idp");
```
In a multi-node deployment use a shared distributed cache so the callback can resolve the state on any node.

## 2. Preserve returnUrl across the whole round trip
Common causes of landing on `/`: the returnUrl isn't put in `AuthenticationProperties.Items`, or `RedirectUri` is set to something else/read back wrongly in the callback.

**Challenge**
```csharp
public async Task<IActionResult> OnGet(string scheme, string? returnUrl)
{
    if (string.IsNullOrEmpty(returnUrl)) returnUrl = "~/";
    if (!Url.IsLocalUrl(returnUrl) && !await _interaction.IsValidReturnUrl(returnUrl))
        throw new ArgumentException("invalid return URL");

    var props = new AuthenticationProperties
    {
        RedirectUri = Url.Page("/ExternalLogin/Callback"),   // our callback, not the returnUrl
        Items =
        {
            { "scheme", scheme },
            { "returnUrl", returnUrl }
        }
    };
    return Challenge(props, scheme);
}
```

**Callback**
```csharp
var result = await HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
if (result?.Succeeded != true) throw new InvalidOperationException("External authentication error");

var scheme = result.Properties!.Items["scheme"]!;
var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

// find/provision local user ...
await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId)
{
    DisplayName = user.DisplayName,
    IdentityProvider = scheme
});
await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

if (await _interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl))
    return Redirect(returnUrl);     // back to /connect/authorize
return Redirect("~/");
```

The returnUrl therefore survives: login page link/form → challenge → (state cache → external provider → state lookup) → callback via `Items` → validated redirect to the authorize endpoint. Also make sure your login page passes the `returnUrl` to the challenge link in the first place (hidden field / route data).
