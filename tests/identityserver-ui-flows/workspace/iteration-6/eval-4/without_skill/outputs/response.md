# Logout flow

## Program.cs
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LogoutUrl = "/Account/Logout";
    options.UserInteraction.LogoutIdParameter = "logoutId";
})
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        // ...existing settings...
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
        BackChannelLogoutSessionRequired = true,
        FrontChannelLogoutUri = "https://app.example.com/signout-oidc"  // optional
    },
    // spa.app unchanged
})
```

## Pages/Account/Logout.cshtml.cs
```csharp
public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public LogoutModel(IIdentityServerInteractionService i) => _interaction = i;

    [BindProperty] public string? LogoutId { get; set; }
    public string? PostLogoutRedirectUri { get; set; }
    public string? SignOutIframeUrl { get; set; }
    public string? ClientName { get; set; }

    public async Task<IActionResult> OnGetAsync(string? logoutId)
    {
        LogoutId = logoutId;
        var ctx = await _interaction.GetLogoutContextAsync(logoutId);
        if (ctx?.ShowSignoutPrompt == false)
            return await OnPostAsync();     // safe to sign out without prompt
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            if (LogoutId == null)
                LogoutId = await _interaction.CreateLogoutContextAsync();

            await HttpContext.SignOutAsync();
        }

        var ctx = await _interaction.GetLogoutContextAsync(LogoutId);
        PostLogoutRedirectUri = ctx?.PostLogoutRedirectUri;
        SignOutIframeUrl = ctx?.SignOutIFrameUrl;
        ClientName = ctx?.ClientName;
        return Page();   // "LoggedOut" view
    }
}
```

## View (after logout)
```html
@if (Model.SignOutIframeUrl != null)
{
    <iframe width="0" height="0" class="signout" src="@Model.SignOutIframeUrl"></iframe>
}
@if (Model.PostLogoutRedirectUri != null)
{
    <a id="return" href="@Model.PostLogoutRedirectUri">Return to @Model.ClientName</a>
    <script>
      window.addEventListener("load", function () {
        var a = document.querySelector("a#return");
        if (a) window.location = a.href;
      });
    </script>
}
```
The iframe must load before redirecting so front-channel clients are notified; that's why the redirect runs on window `load`.

Back-channel: IdentityServer POSTs a logout token (JWT) to `https://app.example.com/bff/backchannel` automatically when the session ends; the client endpoint must validate the token and clear the session. `BackChannelLogoutSessionRequired = true` includes the `sid` claim.
