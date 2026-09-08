# Error Page for IdentityServer

Protocol errors (invalid client, bad redirect URI, etc.) are surfaced by IdentityServer redirecting the browser to your error page with an error id. The page uses `IIdentityServerInteractionService.GetErrorContextAsync` to fetch the details. For security we show only the error code and request id to the user — the full `ErrorDescription` is logged at `Debug` level, never rendered.

## 1. Configure the error URL and query parameter name (Program.cs)

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.ErrorUrl = "/Home/Error";
    options.UserInteraction.ErrorId  = "errorId"; // name of the query string param (default: "errorId")
})
```

## 2. Error page (Pages/Home/Error.cshtml.cs)

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages.Home;

public class ErrorModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly ILogger<ErrorModel> _logger;

    public ErrorModel(
        IIdentityServerInteractionService interaction,
        ILogger<ErrorModel> logger)
    {
        _interaction = interaction;
        _logger = logger;
    }

    // Only safe-to-display values are exposed to the view
    public string? Error { get; set; }
    public string? RequestId { get; set; }

    public async Task<IActionResult> OnGet(string? errorId)
    {
        // Retrieve the protocol error details
        var message = await _interaction.GetErrorContextAsync(errorId);
        if (message is not null)
        {
            Error = message.Error;          // short error code, safe to show
            RequestId = message.RequestId;  // correlation id for support

            // Log the FULL details (including ErrorDescription) at Debug level only
            _logger.LogDebug(
                "IdentityServer error. Error: {Error}, Description: {ErrorDescription}, RequestId: {RequestId}, ClientId: {ClientId}",
                message.Error,
                message.ErrorDescription,   // sensitive — logged, never rendered
                message.RequestId,
                message.ClientId);
        }

        return Page();
    }
}
```

## 3. Error page view (Pages/Home/Error.cshtml)

```html
@page
@model IdentityServer.Pages.Home.ErrorModel

<h1>Something went wrong</h1>

@if (!string.IsNullOrEmpty(Model.Error))
{
    <p>Error: <code>@Model.Error</code></p>
}
@if (!string.IsNullOrEmpty(Model.RequestId))
{
    <p>Request id: <code>@Model.RequestId</code> (quote this to support)</p>
}

@* NOTE: ErrorDescription is intentionally NOT rendered here for security. *@
```

## Why this design

- **`GetErrorContextAsync(errorId)`** returns an `ErrorMessage` with `Error`, `ErrorDescription`, `RequestId`, `ClientId`, `DisplayMode`, and `UiLocales`.
- **Show only `Error` + `RequestId`.** The `RequestId` lets a user reference the incident with support without leaking internals.
- **Never render `ErrorDescription`.** It can contain configuration/protocol detail useful to an attacker. It is written to the log at **`Debug`** level so operators can diagnose issues privately.
- IdentityServer deliberately keeps client-facing error text minimal; the log is the right place for the full picture.
