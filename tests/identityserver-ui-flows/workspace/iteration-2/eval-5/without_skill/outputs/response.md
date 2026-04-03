# Error Page for IdentityServer

Here's how to implement an error page that displays protocol errors.

## Updated Program.cs (relevant section)

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.UserInteraction.ErrorUrl = "/Error";
    })
    // ... rest of configuration
```

## Pages/Error.cshtml.cs

```csharp
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

    public string Error { get; set; }
    public string ErrorDescription { get; set; }
    public string RequestId { get; set; }

    public async Task<IActionResult> OnGet(string errorId)
    {
        var errorContext = await _interaction.GetErrorContextAsync(errorId);

        if (errorContext != null)
        {
            Error = errorContext.Error;
            ErrorDescription = errorContext.ErrorDescription;
            RequestId = errorContext.RequestId;

            _logger.LogWarning("IdentityServer error: {Error} - {Description}", Error, ErrorDescription);
        }

        return Page();
    }
}
```

## Pages/Error.cshtml

```cshtml
@page
@model ErrorPageModel

<h1>Error</h1>

<div>
    <p><strong>Error:</strong> @Model.Error</p>
    <p><strong>Description:</strong> @Model.ErrorDescription</p>
    <p><strong>Request ID:</strong> @Model.RequestId</p>
</div>
```

## Notes

- The error page retrieves error details using `GetErrorContextAsync`
- Error information is displayed to help the user understand what went wrong
- The error is also logged for debugging purposes
