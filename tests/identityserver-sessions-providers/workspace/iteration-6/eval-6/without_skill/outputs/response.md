# CIBA for kiosk.app

## Client

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = GrantTypes.Ciba,
    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" },
    CibaLifetime = 120,        // seconds
    PollingInterval = 5
}
```

Poll mode is the default (and the only one IdentityServer supports): the client polls the token endpoint with the `auth_req_id`.

## Interfaces to implement
1. `IBackchannelAuthenticationUserValidator` – resolves the user from the request (login_hint, id_token_hint, login_hint_token).
2. `IBackchannelAuthenticationUserNotificationService` – tells the user there's a pending request.
Optionally, the approval UI uses `IBackchannelAuthenticationInteractionService`.

```csharp
public class LoginHintUserValidator : IBackchannelAuthenticationUserValidator
{
    public Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();
        if (!string.IsNullOrEmpty(context.LoginHint))
        {
            // TODO: look up the user in your store
            result.SubjectId = context.LoginHint;
        }
        return Task.FromResult(result);
    }
}

public class StubNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly ILogger<StubNotificationService> _logger;
    public StubNotificationService(ILogger<StubNotificationService> logger) => _logger = logger;

    public Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        _logger.LogInformation("CIBA request {Id} for {Subject}, client {Client}, message {Msg}",
            request.InternalId, request.Subject.GetSubjectId(), request.Client.ClientId, request.BindingMessage);
        return Task.CompletedTask;
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    ...
    .AddBackchannelAuthenticationUserValidator<LoginHintUserValidator>();

builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, StubNotificationService>();
```

The client posts to `/connect/ciba` with `login_hint`, scope and secret, gets an `auth_req_id`, and polls `/connect/token` with `grant_type=urn:openid:params:grant-type:ciba`.
