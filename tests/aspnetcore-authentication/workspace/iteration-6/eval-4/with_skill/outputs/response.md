## What's wrong

`SameSiteMode.Strict` on the cookie. The OIDC callback comes back from IdentityServer, a different site, so it is a cross-site navigation. Browsers won't send `SameSite=Strict` cookies on it, so the app doesn't see the session cookie, treats the user as anonymous, issues another challenge, and you loop back to IdentityServer (which already has a session, so it immediately redirects back).

## Fix

Use `Lax` (not `Strict`) for the cookie and keep it Secure:

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies", options =>
{
    options.Cookie.SameSite = SameSiteMode.Lax;   // Not Strict for OIDC callbacks
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
})
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;
});

var app = builder.Build();
app.UseAuthentication();   // before UseAuthorization
app.UseAuthorization();
```

Also check that `UseAuthentication()` comes before `UseAuthorization()` and that the site runs on HTTPS.
