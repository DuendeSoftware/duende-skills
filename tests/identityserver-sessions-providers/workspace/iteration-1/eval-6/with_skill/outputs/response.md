# Configuring CIBA (Client Initiated Backchannel Authentication)

CIBA allows users to authenticate on a different device than the one running the client. It requires the **Enterprise Edition** license.

## Update the kiosk.app Client

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",

    // CIBA grant type for backchannel authentication
    AllowedGrantTypes = { GrantType.Ciba },

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" },

    // Poll delivery mode — client polls token endpoint for result
    CibaLifetime = 300, // 5-minute CIBA request lifetime
    PollingInterval = 5  // Client can poll every 5 seconds
}
```

## Implement IBackchannelAuthenticationUserValidator

This interface validates the backchannel authentication request and identifies the user via `login_hint`:

```csharp
using Duende.IdentityServer.Validation;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    private readonly IUserStore _userStore;

    public CibaUserValidator(IUserStore userStore)
    {
        _userStore = userStore;
    }

    public async Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        // Identify user by login_hint
        if (context.LoginHint != null)
        {
            var user = await _userStore.FindByUsernameAsync(context.LoginHint);
            if (user != null)
            {
                result.Subject = new System.Security.Claims.ClaimsPrincipal(
                    new System.Security.Claims.ClaimsIdentity(
                    [
                        new System.Security.Claims.Claim("sub", user.SubjectId),
                        new System.Security.Claims.Claim("name", user.Username)
                    ], "ciba"));
            }
            else
            {
                result.Error = "unknown_user";
                result.ErrorDescription = "User not found by login_hint";
            }
        }
        else
        {
            result.Error = "unknown_user_id";
            result.ErrorDescription = "login_hint is required";
        }

        return result;
    }
}
```

## Implement IBackchannelAuthenticationUserNotificationService

This interface sends a notification to the user to approve/deny the request:

```csharp
using Duende.IdentityServer.Services;

public class CibaNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushNotificationService _pushService;
    private readonly ILogger<CibaNotificationService> _logger;

    public CibaNotificationService(
        IPushNotificationService pushService,
        ILogger<CibaNotificationService> logger)
    {
        _pushService = pushService;
        _logger = logger;
    }

    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        _logger.LogInformation("Sending CIBA notification for request {InternalId}",
            request.InternalId);

        // Send push notification, email, SMS, etc.
        await _pushService.SendAsync(
            request.Subject.FindFirst("sub")!.Value,
            new
            {
                Message = $"Authentication request from {request.Client.ClientName}",
                RequestId = request.InternalId,
                ApprovalUrl = $"https://identity.example.com/ciba/approve?id={request.InternalId}"
            });
    }
}
```

## Register in DI

```csharp
builder.Services.AddTransient<IBackchannelAuthenticationUserValidator, CibaUserValidator>();
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, CibaNotificationService>();
```

## Key Points

- **Enterprise Edition required** for CIBA
- The client uses `GrantType.Ciba` and poll delivery mode
- `IBackchannelAuthenticationUserValidator` resolves the user from the `login_hint`
- `IBackchannelAuthenticationUserNotificationService` delivers the approval request to the user
- Both interfaces must be implemented and registered — IdentityServer provides no defaults
- After user approves, call `IBackchannelAuthenticationInteractionService.CompleteLoginRequestAsync`