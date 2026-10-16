# Azure AD external login

## OIDC handler
```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("aad", "Azure AD", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/<tenant-id>/v2.0";
        options.ClientId = "<aad-client-id>";
        options.ClientSecret = "<secret from config>";
        options.ResponseType = "code";
        options.UsePkce = true;
        options.CallbackPath = "/signin-aad";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.GetClaimsFromUserInfoEndpoint = true;
        options.MapInboundClaims = false;
        options.SaveTokens = true;

        options.ClaimActions.MapUniqueJsonKey("oid", "oid");
        options.ClaimActions.MapJsonKey("groups", "groups");   // arrays: use MapJsonKey/custom
        options.TokenValidationParameters.NameClaimType = "name";
    });
```
Note: AAD only emits `groups` in the ID token if you configure the "groups" optional claim in the app manifest (`groupMembershipClaims`); over 200 groups becomes `_claim_names` overage.

## Login callback
```csharp
public async Task<IActionResult> OnGet()
{
    var result = await HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
    if (result?.Succeeded != true) throw new Exception("External auth error");

    var principal = result.Principal!;
    var oid = principal.FindFirstValue("oid")
        ?? throw new Exception("Unknown userid");
    var provider = result.Properties!.Items[".AuthScheme"];

    var user = await users.FindByExternalProviderAsync(provider, oid)
               ?? await users.AutoProvisionUserAsync(provider, oid, principal.Claims);

    var additionalClaims = new List<Claim>();
    foreach (var g in principal.FindAll("groups"))
        additionalClaims.Add(new Claim("role", g.Value));      // map to internal type (ideally via group id -> role lookup)

    var sid = principal.FindFirst(JwtClaimTypes.SessionId);
    if (sid != null) additionalClaims.Add(new Claim(JwtClaimTypes.SessionId, sid.Value));

    var props = new AuthenticationProperties();
    var idToken = result.Properties.GetTokenValue("id_token");
    if (idToken != null) props.StoreTokens([new AuthenticationToken { Name = "id_token", Value = idToken }]);

    var isuser = new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.Username,
        IdentityProvider = provider,
        AdditionalClaims = additionalClaims
    };
    await HttpContext.SignInAsync(isuser, props);
    await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
    return Redirect(returnUrl);
}
```
Then expose the internal claims through your `IProfileService` and declare them in `UserClaims`.
