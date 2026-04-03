# Configuring CIBA for the Kiosk Client

CIBA (Client Initiated Backchannel Authentication) enables authentication on a separate device — perfect for your bank kiosk scenario where the user authenticates via their mobile phone.

## Updated kiosk.app Client

```csharp
// In the clients list in Program.cs
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = { GrantType.Ciba },

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" }
}
```

## Required Interface Implementations

You'll need to implement two interfaces for CIBA to function.

### 1. User Validator

This validates the authentication request and identifies the user from the `login_hint`:

```csharp
// CibaUserValidator.cs
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    public async Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        if (context.LoginHint != null)
        {
            // Look up the user by login_hint and return their claims
            result.Subject = new ClaimsPrincipal(new ClaimsIdentity(
                new[]
                {
                    new Claim("sub", context.LoginHint), // Map to actual user sub
                    new Claim("name", "User Name")
                },
                "ciba"
            ));
        }
        else
        {
            result.Error = "missing_login_hint";
        }

        return result;
    }
}
```

### 2. User Notification Service

This notifies the user that an authentication request is pending:

```csharp
// CibaNotificationService.cs
using Duende.IdentityServer.Models;

public class CibaNotificationService : IBackchannelAuthenticationUserNotificationService
{
    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        // Send push notification, SMS, email, etc. to the user
        // request.Subject contains the user's claims
        // request.InternalId is the request identifier
        var sub = request.Subject.FindFirst("sub")?.Value;
        
        // TODO: Implement actual notification delivery
        // e.g., push notification to the user's mobile device
        await Task.CompletedTask;
    }
}
```

## DI Registration

```csharp
// Program.cs
builder.Services.AddTransient<IBackchannelAuthenticationUserValidator, CibaUserValidator>();
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, CibaNotificationService>();
```

## Flow

1. Kiosk sends backchannel auth request to IdentityServer with `login_hint`
2. User validator identifies the user
3. Notification service sends alert to user's device
4. User approves on their phone
5. Kiosk polls token endpoint and receives tokens

The kiosk uses poll mode to check for authentication completion.
