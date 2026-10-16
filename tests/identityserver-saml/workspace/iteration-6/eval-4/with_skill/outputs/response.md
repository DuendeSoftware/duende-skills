# SAML Single Logout in Duende IdentityServer

## How it works
SLO is **front-channel via iframes** (not redirect chains):
1. An SP sends a `LogoutRequest` to `/Saml2/SLO`.
2. IdentityServer ends the local session.
3. It renders a logout page with iframes sending `LogoutRequest`s to all other SPs with active sessions.
4. It collects `LogoutResponse`s.
5. It sends the final `LogoutResponse` to the originating SP.

The callback `/Saml2/SLO/Callback` completes the round-trip. The user must stay on the logout page for the iframes to finish. **Partial logout is normal** (some SPs may not respond) — it's expected, not an error. Short session lifetimes act as the fallback.

## SP registration

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    SingleLogoutServiceUrls =
    [
        new SamlEndpointType
        {
            Location = "https://sp.example.com/saml/slo",
            Binding = SamlBinding.HttpRedirect     // only HTTP-Redirect is supported
        }
    ],
    RequireSignedLogoutResponses = true,           // per-SP override of the global default (true)
    Certificates = [ new ServiceProviderCertificate { Certificate = spCert, Use = KeyUse.Signing } ]
}
```

Global options: `SamlOptions.RequireSignedLogoutResponses`, `LogoutSessionLifetime` (default 5 min), `Endpoints.SingleLogoutServicePath`.

## Production
- Use `ISamlLogoutSessionStore` (EF operational store auto-registers it, or Redis) so multi-node deployments can track which SPs have sessions and correlate responses (`TryRecordResponseAsync`).
- Extension points: `ISamlLogoutNotificationService` (selective SLO targeting), `ISaml2SloResponseGenerator` (success vs partial), `ISaml2FrontChannelLogoutRequestBuilder`, `ILogoutRequestValidator`.
