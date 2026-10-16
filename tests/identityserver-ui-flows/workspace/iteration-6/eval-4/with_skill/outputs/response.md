# Logout flow

## Program.cs
`LogoutUrl` is **not** inferred from the cookie handler; set it explicitly.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LogoutUrl = "/Account/Logout";
})
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        ClientName = "Web Application",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret("secret".Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        AllowedScopes = { "openid", "profile", "email", "api1" },
        RequireConsent = true,

        // back-channel logout
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
        BackChannelLogoutSessionRequired = true
    },
    // spa.app unchanged
})
```
Back-channel notification is automatic: when you call `HttpContext.SignOutAsync()`, IdentityServer (via `IBackChannelLogoutService`) POSTs a logout token (`typ: logout+jwt`) to every client with a `BackChannelLogoutUri`. For .NET clients, the BFF framework handles the endpoint. Prefer back-channel for cross-site setups, since front-channel iframes depend on third-party cookies.

## Pages/Account/Logout.cshtml.cs
```csharp
public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public LogoutModel(IIdentityServerInteractionService interaction) => _interaction = interaction;

    [BindProperty] public string? LogoutId { get; set; }
    public string? PostLogoutRedirectUri { get; set; }
    public string? SignOutIframeUrl { get; set; }
    public string? ClientName { get; set; }
    public bool LoggedOut { get; set; }

    public async Task<IActionResult> OnGet(string? logoutId)
    {
        LogoutId = logoutId;
        var context = await _interaction.GetLogoutContextAsync(logoutId);
        if (context?.ShowSignoutPrompt == false)       // request is signed/trusted
            return await OnPost();
        return Page();                                 // confirmation prompt
    }

    public async Task<IActionResult> OnPost()
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            // capture context BEFORE the session disappears
            LogoutId ??= await _interaction.CreateLogoutContextAsync();

            // 1. End the IdentityServer session (also triggers back-channel notifications)
            await HttpContext.SignOutAsync();
            // 2. If the user logged in externally, also sign out of that provider
            //    (challenge/sign-out the external scheme from User's "idp" claim)
        }

        var context = await _interaction.GetLogoutContextAsync(LogoutId);
        ClientName = context?.ClientName;
        PostLogoutRedirectUri = context?.PostLogoutRedirectUri;
        SignOutIframeUrl = context?.SignOutIFrameUrl;   // front-channel notifications
        LoggedOut = true;
        return Page();
    }
}
```

## Pages/Account/Logout.cshtml (logged-out view)
```html
@page
@model LogoutModel
@if (!Model.LoggedOut)
{
    <form method="post">
        <input type="hidden" asp-for="LogoutId" />
        <p>Would you like to log out?</p>
        <button>Yes</button>
    </form>
}
else
{
    <p>You are now logged out.</p>
    @if (Model.SignOutIframeUrl != null)
    {
        <iframe width="0" height="0" class="signout" src="@Model.SignOutIframeUrl"></iframe>
    }
    @if (Model.PostLogoutRedirectUri != null)
    {
        <a id="return" href="@Model.PostLogoutRedirectUri">Return to @Model.ClientName</a>
        <script>
          window.addEventListener("load", () => {
            const a = document.getElementById("return");
            if (a) window.location = a.href;   // redirect only after iframes have loaded
          });
        </script>
    }
}
```

## Summary
1. End IdentityServer session → 2. sign out external IdP if used → 3. notify clients (iframe `SignOutIFrameUrl` for front-channel; automatic for back-channel) → 4. redirect to `PostLogoutRedirectUri`. Redirect waits for the page `load` event so the iframe notifications complete first. `PostLogoutRedirectUri` is already validated against the client's registered `PostLogoutRedirectUris` by IdentityServer.
