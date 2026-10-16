# Long state + lost returnUrl

## 1. Long `state` – use a distributed cache state data format
The OIDC handler packs the full `AuthenticationProperties` into the `state` parameter. Store them server-side instead:

```csharp
builder.Services.AddDistributedMemoryCache();   // use Redis/SQL in production

builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", "Corporate IdP", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "...";
        options.ClientId = "...";
        options.ClientSecret = "...";
        options.ResponseType = "code";
        options.SaveTokens = false;   // smaller properties
    });

builder.Services.AddOidcStateDataFormatterCache("corporate-idp");
```
`AddOidcStateDataFormatterCache` is an IdentityServer extension that swaps `StateDataFormat` for one that stores the properties in `IDistributedCache` and sends only a short key. With no arguments it applies to all OIDC schemes.

## 2. Preserve returnUrl
Put it in `AuthenticationProperties.Items` when challenging and read it back in the callback.

```csharp
public IActionResult OnGet(string scheme, string? returnUrl)
{
    returnUrl ??= "~/";
    if (!Url.IsLocalUrl(returnUrl) && !_interaction.IsValidReturnUrl(returnUrl))
        throw new ArgumentException("invalid returnUrl");

    var props = new AuthenticationProperties
    {
        RedirectUri = Url.Page("/ExternalLogin/Callback"),
        Items = { { "scheme", scheme }, { "returnUrl", returnUrl } }
    };
    return Challenge(props, scheme);
}
```
Callback:
```csharp
var result = await HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
var returnUrl = result.Properties?.Items["returnUrl"] ?? "~/";
// ... find/provision user, then:
await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId) { IdentityProvider = "corporate-idp" });
await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
if (_interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl)) return Redirect(returnUrl);
return Redirect("~/");
```
Common bug: `RedirectUri` set to the returnUrl itself or items dropped, so the callback lands on "/". `RedirectUri` must be your callback page; the real returnUrl lives in Items (round-tripped via the state cache and then the external cookie).
