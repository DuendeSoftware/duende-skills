# Error page

**Program.cs**
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.ErrorUrl = "/Error";
    options.UserInteraction.ErrorIdParameter = "errorId";
})
```

**Pages/Error.cshtml.cs**
```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ErrorModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly ILogger<ErrorModel> _logger;

    public ErrorModel(IIdentityServerInteractionService interaction, ILogger<ErrorModel> logger)
    { _interaction = interaction; _logger = logger; }

    public string? Error { get; set; }
    public string? RequestId { get; set; }

    public async Task OnGetAsync(string? errorId)
    {
        var message = await _interaction.GetErrorContextAsync(errorId);
        if (message != null)
        {
            Error = message.Error;
            RequestId = message.RequestId;

            _logger.LogDebug(
                "IdentityServer error {Error}, description: {Description}, requestId: {RequestId}, client: {ClientId}, redirect: {RedirectUri}",
                message.Error, message.ErrorDescription, message.RequestId,
                message.ClientId, message.RedirectUri);
        }
    }
}
```

**Error.cshtml**
```html
@page
@model ErrorModel
<h1>Sorry, there was an error</h1>
@if (Model.Error != null)
{
    <p>Error: <code>@Model.Error</code></p>
    <p>Request Id: <code>@Model.RequestId</code></p>
}
```
Razor encodes output automatically. The `ErrorDescription` is only logged (Debug) and never rendered, because it may contain internal details or attacker-controlled text. Note that `GetErrorContextAsync` returns null if the id is missing/expired, so we handle that gracefully.
