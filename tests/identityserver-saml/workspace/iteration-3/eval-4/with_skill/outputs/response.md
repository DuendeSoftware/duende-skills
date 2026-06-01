# Single Logout (SLO) in Duende IdentityServer SAML

## How SLO Works

Duende IdentityServer uses **front-channel logout via iframes** (not redirect chains):

1. An SP sends a `LogoutRequest` to `/Saml2/SLO`
2. IdentityServer ends the local session
3. IdentityServer renders iframes that send `LogoutRequest` messages to all other active SPs
4. It collects `LogoutResponse` messages from the SPs
5. Sends a final `LogoutResponse` to the originating SP

## Configuring SLO on the Service Provider

Add `SingleLogoutServiceUrls` to your `SamlServiceProvider`:

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://sp.example.com/saml/acs",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],
    SingleLogoutServiceUrls =
    [
        new SamlEndpointType
        {
            Location = "https://sp.example.com/saml/slo",
            Binding = SamlBinding.HttpRedirect
        }
    ],
    AllowedScopes = ["openid", "profile"]
}
```

## Key Points

- **Partial logout is normal.** Since SLO uses iframes, some SPs may not respond (blocked by browser, network issues, etc.). This is expected behavior — don't treat it as an error.
- The user must stay on the logout page for iframes to complete.
- Short session lifetimes serve as an SLO fallback for SPs that don't respond.

## Distributed Deployments

For multi-node deployments, configure `ISamlLogoutSessionStore` to persist SLO session state (which SPs have active sessions). Without it, logout state is only in-memory and lost if a different node handles the logout.

Options include EF Core or Redis-backed implementations.
