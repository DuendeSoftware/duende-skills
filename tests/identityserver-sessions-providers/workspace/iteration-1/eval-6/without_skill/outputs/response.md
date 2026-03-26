# Configuring CIBA for the Kiosk Client

CIBA (Client Initiated Backchannel Authentication) allows authentication on a separate device. Here's how to set it up.

## Update the Client

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",
    AllowedGrantTypes = { "urn:openid:params:grant-type:ciba" },
    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" }
}
```

## User Validator

```csharp
public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    public async Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        if (context.LoginHint != null)
        {
            // Look up user by login_hint
            result.Subject = new ClaimsPrincipal(
                new ClaimsIdentity(new[]
                {
                    new Claim("sub", context.LoginHint)
                }, "ciba"));
        }

        return result;
    }
}
```

## Notification Service

```csharp
public class CibaNotificationService : IBackchannelAuthenticationUserNotificationService
{
    public async Task SendLoginRequestAsync(BackchannelUserLoginRequest request)
    {
        // Send push notification, email, or SMS to the user
        // Include the request ID for approval
        Console.WriteLine($"CIBA request {request.InternalId} for user {request.Subject}");
    }
}
```

## Registration

```csharp
builder.Services.AddTransient<IBackchannelAuthenticationUserValidator, CibaUserValidator>();
builder.Services.AddTransient<IBackchannelAuthenticationUserNotificationService, CibaNotificationService>();
```

## Notes

- CIBA uses poll mode by default for clients to check the token endpoint
- The user validator identifies who needs to authenticate
- The notification service tells them about the request