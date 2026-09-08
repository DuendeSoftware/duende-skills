# CIBA User Notification and Approval Flow

Here's how to notify the user of a pending CIBA login and build an approval page in Duende IdentityServer.

## Notification service

Implement `IBackchannelAuthenticationUserNotificationService` and send a push that links to your approval UI. Show the `BindingMessage` so the user can confirm it matches what's on the other device.

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CibaUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushSender _push;
    public CibaUserNotificationService(IPushSender push) => _push = push;

    public async Task SendLoginRequestAsync(
        BackchannelUserLoginRequest request, CancellationToken cancellationToken)
    {
        var subjectId = request.Subject.GetSubjectId();
        var bindingMessage = request.BindingMessage;

        // Link the user to the approval page for this request
        await _push.SendAsync(subjectId,
            title: "Approve sign-in",
            body: $"Verify this code: {bindingMessage}",
            url: $"https://ids.example.com/ciba/approve/{request.InternalId}",
            ct: cancellationToken);
    }
}
```

Register it:

```csharp
builder.Services.AddIdentityServer()
    .AddBackchannelAuthenticationUserNotificationService<CibaUserNotificationService>();
```

## Approval page

Use `IBackchannelAuthenticationInteractionService` to list the current user's pending requests and to complete one.

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Extensions;

public class ApproveModel : PageModel
{
    private readonly IBackchannelAuthenticationInteractionService _ciba;
    public ApproveModel(IBackchannelAuthenticationInteractionService ciba) => _ciba = ciba;

    public async Task OnGetAsync(CancellationToken ct)
    {
        // List the signed-in user's pending CIBA requests
        Pending = await _ciba.GetPendingLoginRequestsForCurrentUserAsync(ct);
    }
    public IEnumerable<BackchannelUserLoginRequest> Pending { get; set; } = [];

    public async Task<IActionResult> OnPostAsync(string internalId, bool approve, CancellationToken ct)
    {
        // Find the request among the user's pending requests
        var pending = await _ciba.GetPendingLoginRequestsForCurrentUserAsync(ct);
        var request = pending.FirstOrDefault(r => r.InternalId == internalId);
        if (request is null) return NotFound();

        // Ownership check: make sure it belongs to the current user
        if (request.Subject.GetSubjectId() != User.GetSubjectId())
            return Forbid();

        if (approve)
        {
            await _ciba.CompleteLoginRequestAsync(new CompleteBackchannelLoginRequest(internalId)
            {
                ScopesValuesConsented = request.ValidatedResources.RawScopeValues
            }, ct);
        }
        else
        {
            // Deny by leaving consented scopes empty
            await _ciba.CompleteLoginRequestAsync(new CompleteBackchannelLoginRequest(internalId)
            {
                ScopesValuesConsented = null
            }, ct);
        }

        return RedirectToPage();
    }
}
```

## Notes

- Show the `BindingMessage` to the user so they can compare it with the device that started the flow.
- Perform an ownership check by comparing the request's subject to the signed-in user before completing.
- Approve by passing the requested scopes; deny by leaving the consented scopes empty/null.
