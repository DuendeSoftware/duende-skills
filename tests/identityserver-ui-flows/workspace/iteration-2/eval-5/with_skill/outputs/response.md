# Error Page Implementation

Here's the error page implementation that configures the error URL, retrieves error details via `IIdentityServerInteractionService`, displays safe information to the user, and logs full details.

## Updated Program.cs (relevant section)

```csharp
builder.Services.AddIdentityServer(options =>
    {
        // Configure error page URL and query parameter
        options.UserInteraction.ErrorUrl = "/Error";
        options.UserInteraction.ErrorId = "errorId";
    })
    // ... rest of configuration
```

## Pages/Error.cshtml

```cshtml
@page
@model ErrorPageModel

<h1>Error</h1>

@if (Model.ErrorMessage != null)
{
    <div class="alert alert-danger">
        <p><strong>Error:</strong> @Model.ErrorMessage.Error</p>
        <p><strong>Request ID:</strong> @Model.ErrorMessage.RequestId</p>
    </div>

    <p>Sorry, there was an error processing your request. Please contact support with the Request ID above.</p>
}
else
{
    <p>An unknown error occurred.</p>
}
```

## Pages/Error.cshtml.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ErrorPageModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly ILogger<ErrorPageModel> _logger;

    public ErrorPageModel(
        IIdentityServerInteractionService interaction,
        ILogger<ErrorPageModel> logger)
    {
        _interaction = interaction;
        _logger = logger;
    }

    public ErrorMessage ErrorMessage { get; set; }

    public async Task<IActionResult> OnGet(string errorId)
    {
        // Retrieve error details using the interaction service
        ErrorMessage = await _interaction.GetErrorContextAsync(errorId);

        if (ErrorMessage != null)
        {
            // Log full error details at Debug level (including ErrorDescription)
            // This is safe for server logs but should NOT be shown to end users
            _logger.LogDebug(
                "IdentityServer error: {Error}, Description: {ErrorDescription}, RequestId: {RequestId}, ClientId: {ClientId}",
                ErrorMessage.Error,
                ErrorMessage.ErrorDescription,
                ErrorMessage.RequestId,
                ErrorMessage.ClientId);
        }

        // Note: The view only displays Error and RequestId — NOT ErrorDescription.
        // ErrorDescription may contain sensitive information and should only be
        // available in server logs for debugging purposes.

        return Page();
    }
}
```

## Key Points

1. **ErrorUrl configuration**: `opt.UserInteraction.ErrorUrl = "/Error"` tells IdentityServer where the error page lives. `opt.UserInteraction.ErrorId = "errorId"` configures the query parameter name.

2. **GetErrorContextAsync**: Called with the `errorId` to retrieve the `ErrorMessage` which contains `Error`, `ErrorDescription`, `RequestId`, `ClientId`, `DisplayMode`, and `UiLocales`.

3. **Safe display**: The view only renders `Error` (the error code) and `RequestId` to the user. `ErrorDescription` is deliberately excluded from the UI for security.

4. **Debug logging**: The full error details including `ErrorDescription` are logged at `Debug` level via `ILogger`, making them available for troubleshooting without exposing them to end users.
