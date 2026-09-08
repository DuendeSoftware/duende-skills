# Configuring `kiosk.app` for CIBA (Poll Mode)

CIBA lets the user authenticate on a *different* device (their phone) than the one running the client (the kiosk). The client requests backchannel authentication, IdentityServer identifies and notifies the user, the user approves on their device, and the client **polls** the token endpoint for the result.

> **Edition note:** CIBA is a **Duende IdentityServer Enterprise Edition** feature.

## Interfaces you must implement

IdentityServer provides **no** working defaults for these two — you must implement and register both:

| Interface | Responsibility |
| --- | --- |
| `IBackchannelAuthenticationUserValidator` | Resolve the `login_hint` to a real user and return their `sub` claim |
| `IBackchannelAuthenticationUserNotificationService` | Deliver the approval prompt to the user (push/SMS/email) |

## 1) Update the `kiosk.app` client

Switch it to the CIBA grant. The client uses `poll` delivery mode (the default for CIBA in IdentityServer): it receives an `auth_req_id` and polls the token endpoint, handling `authorization_pending` / `slow_down`.

```csharp
new Client
{
    ClientId = "kiosk.app",
    ClientName = "Bank Kiosk Application",

    AllowedGrantTypes = GrantTypes.Ciba,   // urn:openid:params:grant-type:ciba

    ClientSecrets = { new Secret("KioskSecret".Sha256()) },
    AllowedScopes = { "openid", "profile", "catalog.read" },
}
```

## 2) User validator — resolve `login_hint` to a `sub`

```csharp
using Duende.IdentityServer.Validation;
using Duende.IdentityServer.Models;
using System.Security.Claims;

public class CibaUserValidator : IBackchannelAuthenticationUserValidator
{
    public Task<BackchannelAuthenticationUserValidationResult> ValidateRequestAsync(
        BackchannelAuthenticationUserValidatorContext context)
    {
        var result = new BackchannelAuthenticationUserValidationResult();

        // The user is identified by login_hint (e.g. a username or email)
        var loginHint = context.LoginHint;

        // Look up your user store here...
        var subjectId = ResolveSubjectFromLoginHint(loginHint);
        if (subjectId is null)
        {
            result.Error = "unknown_user";      // rejects the CIBA request
            return Task.FromResult(result);
        }

        result.Subject = new ClaimsPrincipal(
            new ClaimsIdentity(new[] { new Claim("sub", subjectId) }, "ciba"));

        return Task.FromResult(result);
    }

    private static string? ResolveSubjectFromLoginHint(string? loginHint)
        => loginHint switch { "alice" => "88421113", _ => null };
}
```

## 3) Notification service — tell the user to approve

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CibaUserNotificationService : IBackchannelAuthenticationUserNotificationService
{
    public Task SendLoginRequestAsync(BackchannelUserLoginRequest request, CancellationToken ct)
    {
        var sub = request.Subject.GetSubjectId();   // who to notify
        var bindingMessage = request.BindingMessage; // show to user on both devices
        // request.InternalId is sensitive — do NOT put it in the notification

        // Deliver a push/SMS/email linking to your approval page.
        return Task.CompletedTask;
    }
}
```

## 4) Register everything in DI

```csharp
builder.Services.AddIdentityServer(/* ... */)
    // ... resources/scopes/clients ...
    .AddBackchannelAuthenticationUserNotificationService<CibaUserNotificationService>();

// The user validator is a plain DI registration:
builder.Services.AddTransient<
    IBackchannelAuthenticationUserValidator, CibaUserValidator>();
```

## Poll mode recap

The kiosk client posts to `/connect/ciba`, gets an `auth_req_id`, then repeatedly posts to the token endpoint with grant type `urn:openid:params:grant-type:ciba`. Until the user approves it receives `authorization_pending` (or `slow_down`); once approved it gets tokens; if denied/expired it gets an error. That polling loop is exactly the `poll` delivery mode IdentityServer supports.
