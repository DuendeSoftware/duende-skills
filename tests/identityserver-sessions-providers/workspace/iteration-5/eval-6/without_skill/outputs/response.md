# Configuring `kiosk.app` for CIBA

CIBA (Client Initiated Backchannel Authentication) decouples the device running the client from the device where the user authenticates. In Duende IdentityServer you set the CIBA grant on the client and implement two interfaces: one to resolve the user from the `login_hint`, and one to notify the user so they can approve. The kiosk then polls the token endpoint for the result.

## 1) Client configuration

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",

    AllowedGrantTypes = GrantTypes.Ciba,   // urn:openid:params:grant-type:ciba

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" }
}
```

The client requests `/connect/ciba`, receives an `auth_req_id`, and then polls the token endpoint (`poll` mode), handling `authorization_pending` and `slow_down` until the user approves or the request expires.

## 2) User validator (resolve `login_hint`)

Implement `IBackchannelAuthenticationUserValidator` to turn the `login_hint` into an authenticated subject:

```csharp
using Duende.IdentityServer.Validation;
using System.Security.Claims;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    public Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        var loginHint = context.LoginHint;      // identify the user
        var sub = LookupSubject(loginHint);

        if (sub is null)
        {
            result.Error = "unknown_user";
        }
        else
        {
            result.Subject = new ClaimsPrincipal(
                new ClaimsIdentity(new[] { new Claim("sub", sub) }, "ciba"));
        }

        return Task.FromResult(result);
    }

    private static string? LookupSubject(string? loginHint)
        => loginHint == "alice" ? "88421113" : null;
}
```

## 3) Notification service (notify the user)

Implement `IBackchannelAuthenticationUserNotificationService` to push the approval prompt:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CibaUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    public Task SendLoginRequestAsync(BackchannelUserLoginRequest request, CancellationToken ct)
    {
        var sub = request.Subject.GetSubjectId();
        var bindingMessage = request.BindingMessage;
        // Send a push/SMS/email that links to your approval UI.
        return Task.CompletedTask;
    }
}
```

## 4) Register both in DI

```csharp
builder.Services.AddTransient<
    IBackchannelAuthenticationUserValidator, CibaUserValidator>();

builder.Services.AddTransient<
    IBackchannelAuthenticationUserNotificationService, CibaUserNotificationService>();
```

## Summary

- `kiosk.app` uses `GrantTypes.Ciba` and poll delivery mode.
- `CibaUserValidator` resolves the `login_hint` to a `sub`.
- `CibaUserNotificationService` notifies the user to approve.
- Both interfaces are registered in DI; IdentityServer has no usable default for them.
