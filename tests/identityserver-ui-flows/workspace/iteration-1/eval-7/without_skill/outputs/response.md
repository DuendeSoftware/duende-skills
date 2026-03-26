# Fixing State and ReturnUrl Issues

## The Problem

The OIDC state parameter is too long because it's encoded in the URL. Also, the returnUrl is being lost during the external auth round-trip.

## Fix 1: State Storage

You can store the state server-side. In ASP.NET Core, you can configure a distributed cache and use a custom state data format:

```csharp
builder.Services.AddDistributedMemoryCache();

// Configure the OIDC handler
builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", options =>
    {
        options.Authority = "https://corporate-idp.example.com";
        options.ClientId = "your-client-id";
        options.StateDataFormat = new PropertiesDataFormat(
            new DistributedCacheStateDataFormatter(/* ... */));
    });
```

## Fix 2: Preserve ReturnUrl

Store it in AuthenticationProperties before the Challenge:

```csharp
public IActionResult OnGetLogin(string returnUrl)
{
    var props = new AuthenticationProperties
    {
        RedirectUri = "/callback",
        Items = { { "returnUrl", returnUrl } }
    };
    return Challenge(props, "corporate-idp");
}
```

Then retrieve it in the callback:

```csharp
public async Task<IActionResult> OnGetCallback()
{
    var result = await HttpContext.AuthenticateAsync("Cookies");
    var returnUrl = result.Properties.Items["returnUrl"] ?? "/";

    // ... sign in user ...

    if (Url.IsLocalUrl(returnUrl))
        return Redirect(returnUrl);

    return Redirect("/");
}
```

This ensures the returnUrl survives the round-trip and is validated before redirecting.
