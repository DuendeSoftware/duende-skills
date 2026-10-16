# CIBA notification + approval experience (Enterprise edition)

## Notification service

```csharp
public class PushNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushSender _push;
    private readonly IConfiguration _config;
    public PushNotificationService(IPushSender push, IConfiguration config) { _push = push; _config = config; }

    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request, CancellationToken ct)
    {
        // Link to our approval page. InternalId is a sensitive handle, so it's only in the link
        // delivered over the authenticated push channel; never log it.
        var link = $"{_config["Ciba:ApprovalBaseUrl"]}/Ciba/Approve?id={Uri.EscapeDataString(request.InternalId)}";

        await _push.SendAsync(
            request.Subject.GetSubjectId(),
            $"Sign-in request from {request.Client.ClientName}",
            $"{request.BindingMessage}", link, ct);
    }
}
```

Registration (replaces the built-in log-only service):

```csharp
builder.Services.AddIdentityServer()
    .AddBackchannelAuthenticationUserValidator<MyUserValidator>()
    .AddBackchannelAuthenticationUserNotificationService<PushNotificationService>();
```

## Approval page

```csharp
[Authorize]
public class ApproveModel : PageModel
{
    private readonly IBackchannelAuthenticationInteractionService _ciba;
    private readonly IEventService _events;
    public ApproveModel(IBackchannelAuthenticationInteractionService ciba, IEventService events)
        => (_ciba, _events) = (ciba, events);

    public IEnumerable<BackchannelUserLoginRequest> Pending { get; private set; } = [];
    public BackchannelUserLoginRequest? Request { get; private set; }

    public async Task<IActionResult> OnGetAsync(string? id, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(id))
        {
            Pending = await _ciba.GetPendingLoginRequestsForCurrentUserAsync(ct);
            return Page();
        }

        Request = await Load(id, ct);
        return Request is null ? Forbid() : Page();
    }

    public async Task<IActionResult> OnPostAsync(string id, string button, CancellationToken ct)
    {
        var request = await Load(id, ct);
        if (request is null) return Forbid();

        if (button == "allow")
        {
            await _ciba.CompleteLoginRequestAsync(new CompleteBackchannelLoginRequest(id)
            {
                // originally requested scopes only; server rejects any scope not in the original request
                ScopesValuesConsented = request.ValidatedResources.RawScopeValues
            }, ct);
            // await _events.RaiseAsync(new ConsentGrantedEvent(...));
        }
        else
        {
            await _ciba.CompleteLoginRequestAsync(
                new CompleteBackchannelLoginRequest(id) { ScopesValuesConsented = null }, ct);   // deny
            // await _events.RaiseAsync(new ConsentDeniedEvent(...));
        }
        return RedirectToPage();
    }

    private async Task<BackchannelUserLoginRequest?> Load(string id, CancellationToken ct)
    {
        var request = await _ciba.GetLoginRequestByInternalIdAsync(id, ct);
        // Ownership check: the request must belong to the signed-in user
        if (request is null || request.Subject.GetSubjectId() != User.GetSubjectId()) return null;
        return request;
    }
}
```

## Security-sensitive points
- **Ownership check** on every GET and POST: compare `request.Subject.GetSubjectId()` to the signed-in user; otherwise one user could approve another's request via a guessed/leaked id.
- **`InternalId` is sensitive**: don't put it in the notification text/logs; only in the delivered link; don't expose it beyond the approval page.
- **Binding message**: show it so the user can compare it with the kiosk screen to detect fraudulent requests.
- **Scopes**: approve only the originally requested scopes (a subset is fine; extras are rejected by the server). Don't accept scopes from the form.
- **Deny** by completing with null/empty `ScopesValuesConsented`.
- **Audit**: raise `ConsentGrantedEvent` / `ConsentDeniedEvent`.
- Antiforgery on the POST (Razor Pages default), HTTPS-only link from a configured base URL, and replace the built-in no-op notification service in production.
