# CIBA for kiosk.app (Enterprise edition)

## Client

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = GrantTypes.Ciba,     // replaces ClientCredentials
    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" }
}
```

IdentityServer supports **poll mode**: the client POSTs to `/connect/ciba`, receives an `auth_req_id`, then polls `/connect/token`. It must handle `authorization_pending`, `slow_down`, expiry and denial.

## Interfaces you must implement
IdentityServer ships no working defaults; both must be implemented and registered:

| Interface | Purpose |
|---|---|
| `IBackchannelAuthenticationUserValidator` | validate the request, resolve the user (return `sub`) |
| `IBackchannelAuthenticationUserNotificationService` | tell the user a request awaits (push/email/SMS) |

The approval UI then uses `IBackchannelAuthenticationInteractionService`.

## Stubs

```csharp
public class LoginHintUserValidator : IBackchannelAuthenticationUserValidator
{
    public Task<BackchannelAuthenticationUserValidatorResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidatorResult();
        if (!string.IsNullOrWhiteSpace(context.LoginHint))
        {
            // TODO: look the user up by login_hint in your user store
            result.SubjectId = context.LoginHint;
        }
        return Task.FromResult(result);   // no SubjectId => request rejected
    }
}

public class StubUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly ILogger<StubUserNotificationService> _logger;
    public StubUserNotificationService(ILogger<StubUserNotificationService> logger) => _logger = logger;

    public Task SendLoginRequestAsync(BackchannelUserLoginRequest request, CancellationToken ct)
    {
        // Never put request.InternalId in the message: treat it as sensitive.
        _logger.LogInformation("CIBA request for {Subject}; binding message: {Msg}",
            request.Subject.GetSubjectId(), request.BindingMessage);
        // TODO: send push/SMS/email linking to your approval page
        return Task.CompletedTask;
    }
}
```

(Exact context/result type names depend on the package version; the validator returns the user's `sub`.)

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddBackchannelAuthenticationUserValidator<LoginHintUserValidator>()
    .AddBackchannelAuthenticationUserNotificationService<StubUserNotificationService>();
```

The built-in notification service only logs a URL and must be replaced in production.

## Flow
1. kiosk -> `/connect/ciba` with `login_hint`
2. validator identifies the user
3. pending request stored; notification sent
4. user approves via `CompleteLoginRequestAsync`
5. kiosk polls token endpoint and gets tokens.
