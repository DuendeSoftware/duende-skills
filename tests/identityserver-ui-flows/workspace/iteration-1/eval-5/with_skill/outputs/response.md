# Error Page Implementation

Here's a complete error page implementation for IdentityServer.

## Program.cs — Configure Error URL

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.ErrorUrl = "/Error";
    options.UserInteraction.ErrorId = "errorId"; // default query parameter name
});
```

## Pages/Error.cshtml.cs

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

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

    public string? ErrorCode { get; set; }
    public string? RequestId { get; set; }

    public async Task<IActionResult> OnGet(string errorId)
    {
        // Retrieve error details from IIdentityServerInteractionService
        var errorContext = await _interaction.GetErrorContextAsync(errorId);

        if (errorContext != null)
        {
            // Display only the error code and request ID to the user
            ErrorCode = errorContext.Error;
            RequestId = errorContext.RequestId;

            // Log the full error details including ErrorDescription at Debug level
            _logger.LogDebug(
                "IdentityServer error: {Error}, Description: {ErrorDescription}, RequestId: {RequestId}, ClientId: {ClientId}",
                errorContext.Error,
                errorContext.ErrorDescription,
                errorContext.RequestId,
                errorContext.ClientId);
        }

        return Page();
    }
}
```

## Pages/Error.cshtml

```html
@page
@model IdentityServer.Pages.ErrorModel

<h1>Error</h1>

@if (!string.IsNullOrEmpty(Model.ErrorCode))
{
    <p><strong>Error:</strong> @Model.ErrorCode</p>
}

@if (!string.IsNullOrEmpty(Model.RequestId))
{
    <p><strong>Request ID:</strong> @Model.RequestId</p>
}

<p>An error occurred processing your request. Please contact support with the above request ID.</p>

@* 
    IMPORTANT: Do NOT display ErrorDescription to the user.
    It may contain sensitive information.
    Full details are logged at Debug level for administrators.
*@
```

### Key Points

1. **`opt.UserInteraction.ErrorUrl`** is set to `"/Error"` in Program.cs.
2. **`GetErrorContextAsync(errorId)`** retrieves the error details from `IIdentityServerInteractionService`.
3. **Security**: The page displays only `Error` (error code) and `RequestId` to the user. `ErrorDescription` is **not** rendered in the view.
4. **Logging**: Full error details including `ErrorDescription` are logged at `Debug` level using `ILogger`.
