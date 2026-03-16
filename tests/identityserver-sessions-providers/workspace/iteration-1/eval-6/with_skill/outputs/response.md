# Configuring CIBA for the Kiosk App

CIBA (Client Initiated Backchannel Authentication) allows a user to authenticate on a different device than the one running the client application — for example, a bank kiosk where the user authenticates via their mobile phone.

**Important**: CIBA requires the **Duende IdentityServer Enterprise Edition**.

## 1. Update the kiosk.app Client

Update the `kiosk.app` client configuration to use the CIBA grant type:

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = GrantTypes.Ciba,

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" },

    // Poll mode — client polls the token endpoint for results
    // (this is the default CIBA delivery mode in Duende IdentityServer)
}
```

## 2. Implement IBackchannelAuthenticationUserValidator

This interface validates the incoming CIBA request and identifies the user. The user is identified by their `login_hint`:

```csharp
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    private readonly IUserStore _userStore; // Your user store

    public CibaUserValidator(IUserStore userStore)
    {
        _userStore = userStore;
    }

    public async Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        // Identify the user by login_hint
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
        }

        return result;
    }
}
```

## 3. Implement IBackchannelAuthenticationUserNotificationService

This interface is responsible for notifying the user about the pending authentication request (e.g., via push notification, email, or SMS):

```csharp
using Duende.IdentityServer.Services;

public class CibaUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    private readonly IPushNotificationService _pushService; // Your notification service

    public CibaUserNotificationService(IPushNotificationService pushService)
    {
        _pushService = pushService;
    }

    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        // Send a notification to the user's device
        // The request contains:
        // - request.Subject: the authenticated user
        // - request.InternalId: unique ID for this login request
        // - request.Client: the requesting client
        // - request.ValidatedResources: the requested scopes/resources

        var userId = request.Subject.FindFirst("sub")?.Value;
        await _pushService.SendAsync(userId!, new
        {
            Title = $"Login request from {request.Client.ClientName}",
            Message = "Tap to approve the login request",
            RequestId = request.InternalId
        });
    }
}
```

## 4. Register in DI

```csharp
// Program.cs
builder.Services.AddTransient<IBackchannelAuthenticationUserValidator, CibaUserValidator>();
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, CibaUserNotificationService>();
```

## Complete CIBA Flow

1. **Kiosk** sends a backchannel authentication request to `/connect/ciba` with `login_hint` identifying the user
2. **IdentityServer** calls your `IBackchannelAuthenticationUserValidator` to validate the request and identify the user
3. **IdentityServer** creates a pending login request in the store
4. **IdentityServer** calls your `IBackchannelAuthenticationUserNotificationService` to notify the user
5. **User** reviews and approves/denies the request on their device; your approval UI calls `IBackchannelAuthenticationInteractionService.CompleteLoginRequestAsync`
6. **Kiosk** polls the token endpoint and receives tokens (or an error if denied/timed out)

Both `IBackchannelAuthenticationUserValidator` and `IBackchannelAuthenticationUserNotificationService` **must** be implemented and registered — IdentityServer does not provide default implementations.
