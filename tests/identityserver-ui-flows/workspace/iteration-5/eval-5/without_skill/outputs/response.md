# Error Page for IdentityServer

## 1. Configure the error URL

Point IdentityServer at your error page and (optionally) name the query-string parameter it uses to pass the error id:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.ErrorUrl = "/Home/Error";
    options.UserInteraction.ErrorId = "errorId"; // query string parameter name
})
```

## 2. Error page model

Fetch the error details with `GetErrorContextAsync`. Show the user only the error code and request id; log everything (including the description) at `Debug` level.

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ErrorModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly ILogger<ErrorModel> _logger;

    public ErrorModel(IIdentityServerInteractionService interaction, ILogger<ErrorModel> logger)
    {
        _interaction = interaction;
        _logger = logger;
    }

    public string Error { get; set; }
    public string RequestId { get; set; }

    public async Task OnGetAsync(string errorId)
    {
        var message = await _interaction.GetErrorContextAsync(errorId);
        if (message != null)
        {
            Error = message.Error;
            RequestId = message.RequestId;

            // Log the full details, but only at Debug level
            _logger.LogDebug("Error: {Error} - {Description} (RequestId: {RequestId}, ClientId: {ClientId})",
                message.Error, message.ErrorDescription, message.RequestId, message.ClientId);
        }
    }
}
```

## 3. Error page view

```html
@page
@model ErrorModel

<h2>Sorry, there was an error</h2>

@if (!string.IsNullOrEmpty(Model.Error))
{
    <p>Error code: @Model.Error</p>
}
@if (!string.IsNullOrEmpty(Model.RequestId))
{
    <p>Request ID: @Model.RequestId</p>
}
```

## Security notes

- `GetErrorContextAsync` returns an `ErrorMessage` with `Error`, `ErrorDescription`, `RequestId`, and `ClientId`.
- Only display the `Error` code and `RequestId`. Do **not** render `ErrorDescription` to the user — it may reveal configuration or protocol details useful to an attacker.
- The full description is written to the log at `Debug` level so operators can diagnose the problem without exposing it publicly.
- Give the user the `RequestId` so they can reference the incident when contacting support.
