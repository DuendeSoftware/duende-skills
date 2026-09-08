# CIBA: User Notification + Approval Experience

This covers the two halves of the CIBA user experience: (1) the notification service that pushes a login request to the user's device, and (2) the approval page where the user reviews and approves/denies pending requests.

> CIBA is a **Duende IdentityServer Enterprise Edition** feature.

## Part 1 — Notification service

Implement `IBackchannelAuthenticationUserNotificationService`. Its `SendLoginRequestAsync` receives a `BackchannelUserLoginRequest`. Deliver a push that **links to your approval UI**, showing the `BindingMessage` so the user can compare it on both devices. Treat `InternalId` as a **sensitive** handle — never put it in the outgoing notification.

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CibaUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushSender _push; // your delivery mechanism

    public CibaUserNotificationService(IPushSender push) => _push = push;

    public async Task SendLoginRequestAsync(
        BackchannelUserLoginRequest request, CancellationToken cancellationToken)
    {
        var subjectId = request.Subject.GetSubjectId();   // who to notify
        var bindingMessage = request.BindingMessage;      // show on BOTH devices

        // IMPORTANT: request.InternalId is a sensitive handle to the pending request.
        // Do NOT include it in the push payload / deep link. The approval page loads
        // the user's own pending requests server-side after they authenticate.
        await _push.SendAsync(subjectId,
            title: "Approve sign-in?",
            body: $"Confirm this code matches your other screen: {bindingMessage}",
            deepLink: "https://ids.example.com/ciba/pending",   // no InternalId here
            ct: cancellationToken);
    }
}
```

Register it:

```csharp
builder.Services.AddIdentityServer()
    .AddBackchannelAuthenticationUserNotificationService<CibaUserNotificationService>();
```

## Part 2 — Approval page

Use `IBackchannelAuthenticationInteractionService`. List the current user's pending requests, reload the chosen one **by internal id**, verify ownership, then complete it.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Events;
using Duende.IdentityServer.Extensions;

public class PendingModel : PageModel
{
    private readonly IBackchannelAuthenticationInteractionService _ciba;
    private readonly IEventService _events;

    public PendingModel(IBackchannelAuthenticationInteractionService ciba, IEventService events)
    { _ciba = ciba; _events = events; }

    // List this signed-in user's pending CIBA requests
    public async Task OnGetAsync(CancellationToken ct)
    {
        PendingRequests = await _ciba.GetPendingLoginRequestsForCurrentUserAsync(ct);
    }
    public IEnumerable<BackchannelUserLoginRequest> PendingRequests { get; set; } = [];

    // Approve OR deny a single request identified by its internal id
    public async Task<IActionResult> OnPostAsync(string internalId, bool approve, CancellationToken ct)
    {
        // Reload by internal id
        var request = await _ciba.GetLoginRequestByInternalIdAsync(internalId, ct);
        if (request is null) return NotFound();

        // Verify the request belongs to the signed-in user
        var currentSub = User.GetSubjectId();
        if (request.Subject.GetSubjectId() != currentSub)
            return Forbid();   // not yours — refuse

        CompleteBackchannelLoginRequest complete;
        if (approve)
        {
            // Approve with the ORIGINALLY requested scopes.
            // The server rejects any scope not present in the original CIBA request,
            // so echo the validated/requested scopes rather than inventing new ones.
            complete = new CompleteBackchannelLoginRequest(internalId)
            {
                ScopesValuesConsented = request.ValidatedResources.RawScopeValues,
            };
            await _ciba.CompleteLoginRequestAsync(complete, ct);
            await _events.RaiseAsync(new ConsentGrantedEvent(
                currentSub, request.Client.ClientId, request.ValidatedResources.RawScopeValues,
                null, false));
        }
        else
        {
            // Deny: leave ScopesValuesConsented null/empty.
            complete = new CompleteBackchannelLoginRequest(internalId)
            {
                ScopesValuesConsented = null,
            };
            await _ciba.CompleteLoginRequestAsync(complete, ct);
            await _events.RaiseAsync(new ConsentDeniedEvent(
                currentSub, request.Client.ClientId, request.RequestedResourceIndicators is null
                    ? request.ValidatedResources.RawScopeValues : request.ValidatedResources.RawScopeValues));
        }

        return RedirectToPage();
    }
}
```

## Security-sensitive points

- **`InternalId` is sensitive.** It's the server-side handle to the pending request. Never expose it in the notification/deep link; load pending requests from the authenticated session instead.
- **Ownership check is mandatory.** Always compare `request.Subject.GetSubjectId()` to the signed-in user before completing — otherwise one user could approve another's request.
- **BindingMessage on both devices.** The user must compare the `BindingMessage` shown on the consumption device (kiosk) and their authentication device to defend against session-fixation / phishing.
- **Scope narrowing only.** The server **rejects any scope not in the original CIBA request**; you may consent to a subset but never a superset.
- **Audit.** Raise `ConsentGrantedEvent` / `ConsentDeniedEvent` so approvals and denials are recorded.
