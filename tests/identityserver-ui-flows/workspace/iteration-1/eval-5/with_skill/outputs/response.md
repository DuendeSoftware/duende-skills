# Error Page Implementation

## 1. Configure Error URL in Program.cs

```csharp
builder.Services.AddIdentityServer(opt =>
{
    opt.UserInteraction.ErrorUrl = "/Error";
    opt.UserInteraction.ErrorId = "errorId"; // query string parameter name
});
```

## 2. Error Page Model

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

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
        var errorContext = await _interaction.GetErrorContextAsync(errorId);

        if (errorContext != null)
        {
            // Only expose error code and request ID to the user
            ErrorCode = errorContext.Error;
            RequestId = errorContext.RequestId;

            // Log the FULL error details at Debug level (including ErrorDescription)
            _logger.LogDebug(
                "IdentityServer error: {Error}, Description: {ErrorDescription}, " +
                "RequestId: {RequestId}, ClientId: {ClientId}",
                errorContext.Error,
                errorContext.ErrorDescription,
                errorContext.RequestId,
                errorContext.ClientId);
        }

        return Page();
    }
}
```

## 3. Error Razor View

```html
@page
@model ErrorModel

<h2>Error</h2>

<p>Sorry, there was an error processing your request.</p>

<dl>
    <dt>Error</dt>
    <dd>@Model.ErrorCode</dd>

    <dt>Request ID</dt>
    <dd>@Model.RequestId</dd>
</dl>

@* IMPORTANT: Do NOT display ErrorDescription to the user for security reasons *@
<p>Please contact support and reference the Request ID above.</p>
```

## Key Points

1. **`opt.UserInteraction.ErrorUrl`**: Set to `/Error` so IdentityServer redirects to this page on protocol errors.
2. **`opt.UserInteraction.ErrorId`**: The query parameter name (default: `errorId`).
3. **`GetErrorContextAsync(errorId)`**: Retrieves the `ErrorMessage` with `Error`, `ErrorDescription`, `RequestId`, and `ClientId`.
4. **Security**: Only `Error` and `RequestId` are shown to the user. `ErrorDescription` is NOT rendered — it may contain sensitive details.
5. **Logging**: Full error details including `ErrorDescription` are logged at `Debug` level for troubleshooting.
