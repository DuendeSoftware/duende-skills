# Configuring CIBA for the Kiosk App

CIBA (Client Initiated Backchannel Authentication) enables authentication on a separate device from the client application. Here's how to configure it for the kiosk app.

## 1. Update the kiosk.app Client

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = { GrantType.Ciba },

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" }
}
```

## 2. User Validator

You need to implement an interface to validate and identify the user from the CIBA request:

```csharp
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    public Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        // Identify user by login_hint
        if (!string.IsNullOrEmpty(context.LoginHint))
        {
            // Look up user by login_hint (e.g., username or email)
            result.Subject = new ClaimsPrincipal(new ClaimsIdentity(
                new[]
                {
                    new Claim("sub", context.LoginHint),
                    new Claim("name", "User " + context.LoginHint)
                },
                "ciba"
            ));
        }

        return Task.FromResult(result);
    }
}
```

## 3. Notification Service

You need to implement a service that notifies the user about the authentication request:

```csharp
using Duende.IdentityServer.Services;

public class CibaNotificationService : IBackchannelAuthenticationUserNotificationService
{
    public Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        // Send push notification, SMS, email, etc. to the user
        // request.InternalId — unique ID to reference this request
        // request.Subject — the user to notify
        // request.Client — the requesting client

        Console.WriteLine($"CIBA request {request.InternalId} for user {request.Subject.FindFirst("sub")?.Value}");

        return Task.CompletedTask;
    }
}
```

## 4. Register Services

```csharp
builder.Services.AddTransient<IBackchannelAuthenticationUserValidator, CibaUserValidator>();
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, CibaNotificationService>();
```

## Flow

1. Kiosk sends a request to `/connect/ciba` with `login_hint`
2. IdentityServer validates the user via your `IBackchannelAuthenticationUserValidator`
3. IdentityServer notifies the user via your `IBackchannelAuthenticationUserNotificationService`
4. User approves/denies on their device
5. Kiosk polls the token endpoint to get the result

The poll mode is used by default — the kiosk application periodically checks the token endpoint for the authentication result.
