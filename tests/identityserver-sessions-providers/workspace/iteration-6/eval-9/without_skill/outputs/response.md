# CIBA notification and approval

## Notification service

```csharp
public class PushNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushSender _push;
    private readonly IConfiguration _config;

    public PushNotificationService(IPushSender push, IConfiguration config) { _push = push; _config = config; }

    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        var baseUrl = _config["Ciba:ApprovalBaseUrl"]; // fixed, configured URL
        var url = $"{baseUrl}/Ciba/Consent?id={Uri.EscapeDataString(request.InternalId)}";
        var subjectId = request.Subject.GetSubjectId();

        await _push.SendAsync(subjectId,
            title: "Sign-in request",
            body: $"{request.Client.ClientName} wants to sign you in. {request.BindingMessage}",
            link: url);
    }
}
```

Registration:

```csharp
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, PushNotificationService>();
builder.Services.AddIdentityServer()
    .AddBackchannelAuthenticationUserValidator<MyUserValidator>();
```

## Razor Page: `Pages/Ciba/Consent.cshtml.cs`

```csharp
[Authorize]
public class ConsentModel : PageModel
{
    private readonly IBackChannelAuthenticationInteractionService _ciba;
    public ConsentModel(IBackChannelAuthenticationInteractionService ciba) => _ciba = ciba;

    public IEnumerable<BackchannelUserLoginRequest> Pending { get; set; } = [];
    public BackchannelUserLoginRequest? Request { get; set; }

    public async Task<IActionResult> OnGet(string? id)
    {
        if (id is null)
        {
            Pending = await _ciba.GetPendingLoginRequestsForCurrentUserAsync();
            return Page();
        }
        Request = await _ciba.GetLoginRequestByInternalIdAsync(id);
        if (Request is null || Request.Subject.GetSubjectId() != User.GetSubjectId())
            return NotFound();
        return Page();
    }

    public async Task<IActionResult> OnPost(string id, string button)
    {
        var request = await _ciba.GetLoginRequestByInternalIdAsync(id);
        if (request is null || request.Subject.GetSubjectId() != User.GetSubjectId())
            return NotFound();

        var result = button == "yes"
            ? new CompleteBackchannelLoginRequest(id) { ScopesValuesConsented = request.ValidatedResources.RawScopeValues }
            : new CompleteBackchannelLoginRequest(id);   // no scopes = denied

        await _ciba.CompleteLoginRequestAsync(result);
        return RedirectToPage("/Ciba/All");
    }
}
```

## Security notes
- Always verify the request's subject equals the signed-in user (IDOR protection) – on both GET and POST.
- Use antiforgery on the POST (Razor Pages does it by default).
- Approve only the requested scopes; don't let the form post scopes.
- Don't put secrets in push payloads; build the link from configured base URL (avoid open redirect/phishing); the internal id is not secret but must be unguessable and tied to the auth.
- Display the binding message and client name so the user can detect fraudulent requests; require a fresh login/MFA for approval of sensitive operations.
- Requests expire (`CibaLifetime`); handle expired/missing requests.
