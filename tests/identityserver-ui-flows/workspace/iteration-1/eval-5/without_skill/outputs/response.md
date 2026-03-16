# Error Page for IdentityServer

Here's an error page implementation.

## Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Configure error handling
    options.UserInteraction.ErrorUrl = "/Error";
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

    public ErrorModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public string Error { get; set; }
    public string ErrorDescription { get; set; }
    public string RequestId { get; set; }

    public async Task<IActionResult> OnGet(string errorId)
    {
        var context = await _interaction.GetErrorContextAsync(errorId);

        if (context != null)
        {
            Error = context.Error;
            ErrorDescription = context.ErrorDescription;
            RequestId = context.RequestId;
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

@if (!string.IsNullOrEmpty(Model.Error))
{
    <p><strong>Error:</strong> @Model.Error</p>
}

@if (!string.IsNullOrEmpty(Model.ErrorDescription))
{
    <p><strong>Description:</strong> @Model.ErrorDescription</p>
}

@if (!string.IsNullOrEmpty(Model.RequestId))
{
    <p><strong>Request ID:</strong> @Model.RequestId</p>
}
```

### Notes

- Use `IIdentityServerInteractionService.GetErrorContextAsync` to retrieve error details.
- Display error information to help users understand what went wrong.
- Include the request ID so support teams can track the issue.
