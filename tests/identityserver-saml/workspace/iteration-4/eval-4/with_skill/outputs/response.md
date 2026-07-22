# Single Logout (SLO) with Duende IdentityServer SAML

## How SAML SLO Works in Duende IdentityServer

Duende IdentityServer implements **front-channel Single Logout via iframes**, not redirect chains. This is an important distinction from how some other IdPs work. Here's the step-by-step flow:

```
1. User clicks "Sign Out" at a Service Provider (SP)
2. SP sends a SAML LogoutRequest to the IdP's /Saml2/SLO endpoint
3. IdentityServer ends the user's local IdP session
4. IdentityServer renders a logout page containing hidden iframes
5. Each iframe sends a LogoutRequest to every other SP that has an active session for this user
6. SPs receive the LogoutRequest, terminate their local sessions, and return a LogoutResponse via iframe
7. IdentityServer waits briefly for responses, then sends a final LogoutResponse back to the originating SP
```

**Key characteristics:**
- **Partial logout is normal and expected** — some SPs may not respond to the iframe requests (blocked by browser, slow network, etc.). IdentityServer does not treat this as an error.
- **The user must stay on the logout page** for iframe-based notifications to complete. If the user navigates away mid-logout, some SPs may not be notified.
- **HTTP-Redirect binding is required for SLO** (unlike ACS which requires HTTP-POST). LogoutRequests and LogoutResponses travel via HTTP-Redirect binding.

---

## SLO Endpoints

| Endpoint | Path | Purpose |
|----------|------|---------|
| SLO Handler | `/Saml2/SLO` | Receives LogoutRequest from an SP or LogoutResponse from notified SPs |
| SLO Callback | `/Saml2/SLO/Callback` | Completes the SLO round-trip after all notifications are sent |

These paths are configurable via `SamlOptions.Endpoints.SingleLogoutServicePath` and `SingleLogoutCallbackPath`.

---

## SP Registration: What to Configure for SLO

SLO requires configuring the `SingleLogoutServiceUrls` property on each `SamlServiceProvider`. Without it, the IdP cannot send logout notifications to that SP.

```csharp
new SamlServiceProvider
{
    EntityId = "https://crm.contoso.com",
    DisplayName = "Contoso CRM",

    // ACS — where the IdP posts the SAML assertion (HTTP-POST only)
    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://crm.contoso.com/saml/acs",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],

    // SLO — where the IdP sends logout notifications (HTTP-Redirect only)
    SingleLogoutServiceUrls =
    [
        new SamlEndpointType
        {
            Location = "https://crm.contoso.com/saml/slo",
            Binding = SamlBinding.HttpRedirect  // only HttpRedirect is supported for SLO
        }
    ],

    AllowedScopes = ["openid", "profile", "email"],
    SigningBehavior = SamlSigningBehavior.SignAssertion,
    Enabled = true
}
```

> **Binding matters**: SLO only supports `SamlBinding.HttpRedirect`. Do not use `HttpPost` for `SingleLogoutServiceUrls`.

---

## Per-SP SLO Security Setting: RequireSignedLogoutResponses

By default, IdentityServer requires that SPs sign their `LogoutResponse` messages. You can override this globally or per-SP:

```csharp
// Global default (true = require signed logout responses from all SPs)
.AddSaml(saml =>
{
    saml.RequireSignedLogoutResponses = true; // default
})

// Per-SP override (null = use global default)
new SamlServiceProvider
{
    EntityId = "https://legacy-sp.example.com",
    RequireSignedLogoutResponses = false, // override for this SP only
    // ...
}
```

---

## Session Lifetime Configuration

SLO state tracking uses two configurable timeouts:

```csharp
.AddSaml(saml =>
{
    // How long sign-in state is retained (default: 15 minutes)
    saml.SigninStateLifetime = TimeSpan.FromMinutes(15);

    // How long SLO session tracking state is retained (default: 5 minutes)
    saml.LogoutSessionLifetime = TimeSpan.FromMinutes(5);
});
```

Short session lifetimes serve as a **SLO fallback**: even if front-channel logout fails (user closed browser, blocked iframes), the SP session will expire naturally.

---

## Distributed Deployments: ISamlLogoutSessionStore

In a single-node deployment, SLO session state is stored in-memory. For multi-node deployments (load balanced, Kubernetes), you need a distributed store so all nodes share logout session state.

The `AddOperationalStore()` (EF Core operational store) automatically registers an EF Core implementation of `ISamlLogoutSessionStore` — nothing extra needed:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
// ISamlLogoutSessionStore is automatically registered by AddOperationalStore
```

For a custom implementation (Redis, etc.):

```csharp
// Custom ISamlLogoutSessionStore — key interface for distributed SLO
public class RedisSamlLogoutSessionStore : ISamlLogoutSessionStore
{
    // Track active sessions for a user (called at SSO time)
    public Task StoreAsync(string subjectId, string sessionId,
        string spEntityId, CancellationToken ct) { /* ... */ }

    // Retrieve logout session state (called at SLO time)
    public Task<SamlLogoutSession?> GetAsync(string sessionId, CancellationToken ct)
    { /* ... */ }

    // Record whether a notified SP responded successfully
    // RequestId correlates the outgoing LogoutRequest with the incoming LogoutResponse
    public Task<bool> TryRecordResponseAsync(
        string requestId, string issuer, bool success, CancellationToken ct)
    { /* ... */ }

    // Remove session after logout is complete
    public Task RemoveAsync(string sessionId, CancellationToken ct) { /* ... */ }
}
```

`SamlLogoutSession` properties you'll use:
- `SkippedSpCount` (int) — how many SP notifications were skipped
- `ExpiresAtUtc` (DateTime) — when this session tracking entry expires
- `ExpectedResponses` (Dictionary) — maps RequestId → SP EntityId for response correlation

Register the custom store:

```csharp
builder.Services.AddSingleton<ISamlLogoutSessionStore, RedisSamlLogoutSessionStore>();
```

---

## Customizing SLO Behavior

### Selective SP Notification: ISamlLogoutNotificationService

By default, IdentityServer notifies all SPs with active sessions. Implement `ISamlLogoutNotificationService` to control which SPs get notified:

```csharp
public class CustomLogoutNotificationService : ISamlLogoutNotificationService
{
    public Task<SamlLogoutNotificationResult> GetLogoutNotificationsAsync(
        SamlLogoutNotificationContext context, CancellationToken ct)
    {
        // Filter out SPs you don't want to notify
        var toNotify = context.Sessions
            .Where(s => s.SpEntityId != "https://skip-this-sp.example.com")
            .ToList();

        // Returns: Messages (collection of SamlLogoutRequestContext), SkippedCount (int)
        return Task.FromResult(new SamlLogoutNotificationResult
        {
            Messages = toNotify.Select(s => BuildRequest(s)).ToList(),
            SkippedCount = context.Sessions.Count - toNotify.Count
        });
    }
}
```

### Custom LogoutResponse Generation: ISaml2SloResponseGenerator

```csharp
public class CustomSloResponseGenerator : ISaml2SloResponseGenerator
{
    public Task<SamlLogoutResponse> GenerateResponseAsync(
        SamlLogoutResponseContext context, CancellationToken ct)
    {
        // Customize the response based on whether logout was complete or partial
        var status = context.PartialLogout
            ? SamlStatusCode.PartialLogout
            : SamlStatusCode.Success;

        return Task.FromResult(new SamlLogoutResponse { /* ... */ });
    }
}
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| SP not notified at logout | `SingleLogoutServiceUrls` not configured | Add `SingleLogoutServiceUrls` to the SP registration |
| Logout fails with binding error | Using `HttpPost` for SLO | Use `SamlBinding.HttpRedirect` for `SingleLogoutServiceUrls` |
| SLO state lost on second node | In-memory logout session store | Add `AddOperationalStore()` or custom `ISamlLogoutSessionStore` |
| User sees partial logout warning always | Some SPs don't respond to iframe notifications | This is expected. Front-channel SLO is best-effort. |
| SLO loops back to IdP | SP's SLO endpoint sends a new LogoutRequest instead of a LogoutResponse | SP configuration issue — SP must check if the incoming message is a request or response |

---

## Summary Checklist

- [ ] Add `SingleLogoutServiceUrls` with `SamlBinding.HttpRedirect` to each SP
- [ ] Ensure SP signing certificates are configured if `RequireSignedLogoutResponses = true`
- [ ] For multi-node deployments: add `AddOperationalStore()` or a custom `ISamlLogoutSessionStore`
- [ ] Set appropriate `LogoutSessionLifetime` in `SamlOptions`
- [ ] Verify the login UI calls `DenyAuthenticationAsync` on user cancel (affects logout flows too)
- [ ] Accept that partial logout is normal — don't alert on it
