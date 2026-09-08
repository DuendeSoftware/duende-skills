# Single Logout (SLO) in Duende IdentityServer

## How it works: front-channel logout via iframes

Duende IdentityServer implements SAML Single Logout using **front-channel logout driven by iframes** — *not* a chain of browser redirects hopping from SP to SP. The flow is:

1. An SP sends a `LogoutRequest` to the IdP's SLO endpoint (`/Saml2/SLO`).
2. IdentityServer ends the user's **local** session.
3. It renders a logout page containing **iframes**, one per other active SP, each carrying a `LogoutRequest` to that SP's Single Logout endpoint.
4. Each SP processes its iframe request and returns a `LogoutResponse`.
5. Once responses are collected (or the page times out), IdentityServer sends a final `LogoutResponse` back to the SP that originated the logout.

Using iframes means all SPs are notified in **parallel** and the outcome of one SP doesn't block the others.

### Partial logout is normal

Because it's front-channel, some SPs may not respond — they might be down, slow, or block third-party framing. **Partial logout is expected behavior, not an error.** Don't build logic that treats a missing SP response as a failure. Two important operational notes:

- The user must **stay on the logout page** long enough for the iframes to complete.
- Configure **short session lifetimes** as an SLO fallback so any session that wasn't cleanly logged out still expires quickly.

## What to configure on the SP registration

Configure `SingleLogoutServiceUrls` on the `SamlServiceProvider`. SLO endpoints use the **HTTP-Redirect** binding:

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "Example SP",

    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://sp.example.com/acs",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],

    // Single Logout endpoint(s) — HTTP-Redirect binding
    SingleLogoutServiceUrls =
    [
        new SamlEndpointType
        {
            Location = "https://sp.example.com/saml/slo",
            Binding = SamlBinding.HttpRedirect
        }
    ],

    AllowedScopes = ["openid", "profile", "email"]
}
```

An SP without a `SingleLogoutServiceUrls` entry simply won't be notified during SLO.

## Distributed / multi-node deployments

If you run IdentityServer on multiple nodes behind a load balancer, the "which SPs have active sessions" tracking must be shared across nodes. Configure a distributed **`ISamlLogoutSessionStore`** (e.g., EF Core or Redis) so the SLO round-trip works no matter which node handles each iframe callback.

> If you use `AddOperationalStore()` (EF Core), the EF implementations of both `ISamlSigninStateStore` and `ISamlLogoutSessionStore` are registered automatically — you don't need to wire them up separately.

You can also customize SLO behavior via extensibility points such as `ISamlLogoutNotificationService` (selective targeting of which SPs to notify) and `ISaml2SloResponseGenerator` (custom success vs. partial-logout responses).

## Summary

- SLO = **front-channel logout via iframes**, parallel notification, not redirect chains.
- Configure `SingleLogoutServiceUrls` with `SamlEndpointType` + `SamlBinding.HttpRedirect` per SP.
- **Partial logout is normal** — don't treat non-responding SPs as errors; lean on short session lifetimes.
- For multi-node, use a distributed **`ISamlLogoutSessionStore`**.
