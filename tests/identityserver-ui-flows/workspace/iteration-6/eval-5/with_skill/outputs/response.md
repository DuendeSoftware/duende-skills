# Error page

## Program.cs
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.ErrorUrl = "/Error";
    options.UserInteraction.ErrorIdParameter = "errorId";   // query-string parameter name (default "errorId")
})
```

## Pages/Error.cshtml.cs
```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ErrorModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly ILogger<ErrorModel> _logger;

    public ErrorModel(IIdentityServerInteractionService interaction, ILogger<ErrorModel> logger)
    { _interaction = interaction; _logger = logger; }

    public string? Error { get; private set; }
    public string? RequestId { get; private set; }

    public async Task OnGet(string? errorId)
    {
        var context = await _interaction.GetErrorContextAsync(errorId);
        if (context is null) return;       // missing/expired id – show generic message

        // Shown to the user: code + request id only
        Error = context.Error;
        RequestId = context.RequestId;

        // Full details go to the log only, at Debug level
        _logger.LogDebug(
            "IdentityServer error {Error}: {ErrorDescription} (RequestId {RequestId}, Client {ClientId}, DisplayMode {DisplayMode}, UiLocales {UiLocales})",
            context.Error, context.ErrorDescription, context.RequestId,
            context.ClientId, context.DisplayMode, context.UiLocales);
    }
}
```

## Pages/Error.cshtml
```html
@page
@model ErrorModel
<h1>Sorry, there was an error</h1>
@if (Model.Error is not null)
{
    <p>Error code: <code>@Model.Error</code></p>
    <p>Request ID: <code>@Model.RequestId</code></p>
}
else
{
    <p>An unexpected error occurred.</p>
}
```

## Why this shape
- Errors are usually misconfiguration; the page tells the user something went wrong without exposing `ErrorDescription` (may leak internals or contain attacker-influenced text). Razor HTML-encodes the displayed values.
- Support staff correlate the **RequestId** with the Debug-level server log (enable `Duende.IdentityServer` at Debug in `appsettings.json`'s `Logging:LogLevel`).
- Note: only non-"safe" errors (e.g. `invalid_request`, `invalid_scope`, `unauthorized_client`) reach this page; `login_required`, `consent_required`, `access_denied` etc. are returned directly to the client's redirect_uri.
