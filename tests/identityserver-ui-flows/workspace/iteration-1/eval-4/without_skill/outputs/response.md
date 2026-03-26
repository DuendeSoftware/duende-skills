# Logout Flow

## Configure Logout URL

```csharp
builder.Services.AddIdentityServer(opt =>
{
    opt.UserInteraction.LogoutUrl = "/Account/Logout";
});
```

## Update web.app Client

```csharp
new Client
{
    ClientId = "web.app",
    // ... existing config ...
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel"
}
```

## Logout Page

```csharp
public class LogoutModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LogoutModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public string PostLogoutRedirectUri { get; set; }
    public string SignOutIframeUrl { get; set; }

    public async Task<IActionResult> OnGet(string logoutId)
    {
        var context = await _interaction.GetLogoutContextAsync(logoutId);

        await HttpContext.SignOutAsync();

        PostLogoutRedirectUri = context?.PostLogoutRedirectUri;
        SignOutIframeUrl = context?.SignOutIFrameUrl;

        return Page();
    }
}
```

## Razor View

```html
@page
@model LogoutModel

<h2>Logged Out</h2>

@if (Model.SignOutIframeUrl != null)
{
    <iframe src="@Model.SignOutIframeUrl" width="0" height="0"></iframe>
}

@if (Model.PostLogoutRedirectUri != null)
{
    <a href="@Model.PostLogoutRedirectUri">Return to Application</a>
}
```
