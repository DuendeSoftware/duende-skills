# Configuring CIBA for the Kiosk Client

CIBA (Client Initiated Backchannel Authentication) allows a user to authenticate on a different device than the one running the client. This is ideal for your bank kiosk scenario — the user at the kiosk authenticates via their mobile phone.

**Important**: CIBA requires the **Duende IdentityServer Enterprise Edition**.

## Updated kiosk.app Client

The kiosk.app client needs to be updated to use the CIBA grant type:

```csharp
// In the clients list in Program.cs
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = GrantTypes.Ciba,

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" },

    // Poll mode — the kiosk polls the token endpoint for results
    CibaLifetime = 300, // 5 minutes for user to respond
    PollingInterval = 5  // poll every 5 seconds
}
```

## Required Interface Implementations

CIBA requires you to implement two interfaces. IdentityServer does not provide default implementations — you must implement and register both.

### 1. IBackchannelAuthenticationUserValidator

This interface validates the backchannel authentication request and identifies the user. The kiosk sends a `login_hint` to identify the user.

```csharp
// CibaUserValidator.cs
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    private readonly IUserStore _userStore; // Your user lookup service

    public CibaUserValidator(IUserStore userStore)
    {
        _userStore = userStore;
    }

    public async Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        // Identify the user from the login_hint
        if (context.LoginHint != null)
        {
            var user = await _userStore.FindByUsernameAsync(context.LoginHint);
            if (user != null)
            {
                result.Subject = new ClaimsPrincipal(new ClaimsIdentity(
                    new[]
                    {
                        new Claim("sub", user.SubjectId),
                        new Claim("name", user.DisplayName)
                    },
                    "ciba"
                ));
            }
            else
            {
                result.Error = "unknown_user";
                result.ErrorDescription = "No user found matching the login_hint.";
            }
        }
        else
        {
            result.Error = "missing_login_hint";
            result.ErrorDescription = "A login_hint is required to identify the user.";
        }

        return result;
    }
}
```

### 2. IBackchannelAuthenticationUserNotificationService

This interface is responsible for notifying the user that an authentication request is pending. You implement the actual delivery mechanism (push notification, email, SMS, etc.).

```csharp
// CibaUserNotificationService.cs
using Duende.IdentityServer.Models;

public class CibaUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushNotificationService _pushService; // Your notification service

    public CibaUserNotificationService(IPushNotificationService pushService)
    {
        _pushService = pushService;
    }

    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        // Send a push notification to the user's mobile device
        // The request contains:
        //   - request.Subject: the authenticated user's claims principal
        //   - request.InternalId: the unique ID for this CIBA request
        //   - request.Client: the client that initiated the request
        //   - request.ValidatedResources: the requested scopes

        var sub = request.Subject.FindFirst("sub")?.Value;
        await _pushService.SendAsync(sub!, new
        {
            Title = "Authentication Request",
            Body = $"The kiosk at {request.Client.ClientName} is requesting access. Please approve or deny.",
            RequestId = request.InternalId
        });
    }
}
```

## DI Registration

Both interfaces must be registered in the DI container:

```csharp
// Program.cs
builder.Services.AddTransient<IBackchannelAuthenticationUserValidator, CibaUserValidator>();
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, CibaUserNotificationService>();
```

## CIBA Flow Summary

1. The kiosk sends a backchannel authentication request to `/connect/ciba` with a `login_hint`
2. `IBackchannelAuthenticationUserValidator` validates the hint and returns the user's `sub` claim
3. IdentityServer creates a pending login request
4. `IBackchannelAuthenticationUserNotificationService` sends a notification to the user's device
5. The user reviews and approves/denies on their mobile device
6. Your approval UI calls `IBackchannelAuthenticationInteractionService.CompleteLoginRequestAsync`
7. The kiosk polls the token endpoint and receives tokens once approved

The kiosk uses **poll mode** — it periodically calls the token endpoint to check if the user has approved the request.
