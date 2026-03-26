# Error Page

## Program.cs Configuration

```csharp
builder.Services.AddIdentityServer(opt =>
{
    opt.UserInteraction.ErrorUrl = "/Error";
});
```

## Error Page

```csharp
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
    public string Description { get; set; }
    public string RequestId { get; set; }

    public async Task<IActionResult> OnGet(string errorId)
    {
        var context = await _interaction.GetErrorContextAsync(errorId);
        if (context != null)
        {
            Error = context.Error;
            Description = context.ErrorDescription;
            RequestId = context.RequestId;

            _logger.LogError("Protocol error: {Error} - {Description}", Error, Description);
        }
        return Page();
    }
}
```

## Razor View

```html
@page
@model ErrorModel

<h1>Error</h1>
<p><strong>Error:</strong> @Model.Error</p>
<p><strong>Description:</strong> @Model.Description</p>
<p><strong>Request ID:</strong> @Model.RequestId</p>
```

This shows the error details to the user so they can report issues.
