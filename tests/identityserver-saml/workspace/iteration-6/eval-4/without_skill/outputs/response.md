# SAML Single Logout (SLO)

Flow:
- **SP-initiated**: SP sends a `LogoutRequest` (signed, with NameID and SessionIndex) to IdentityServer's SLO endpoint. IdentityServer validates it, finds the user's session, sends `LogoutRequest`s to other participating SPs (front-channel via redirect/POST binding), ends the local session and sends a `LogoutResponse` back to the initiating SP.
- **IdP-initiated**: when the user logs out at IdentityServer, it notifies each SAML SP that has a session.

SP registration needs:
- A `SingleLogoutServiceUrl` (and binding, Redirect or POST) for the SP.
- Signing certificates if you require signed logout requests (`RequireSignedLogoutRequests`-style option) and the SP's public cert to validate.
- Session tracking so a SessionIndex is recorded per SP (IdentityServer's server-side sessions help for reliability).
- Metadata on the SP side listing IdP's `SingleLogoutService` endpoint.

```csharp
new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    SingleLogoutServiceUrl = new Uri("https://sp.example.com/slo"),
    SingleLogoutServiceBinding = SamlBinding.HttpRedirect,
    SigningCertificates = { spCert }
}
```

Property names are approximate; check the docs. Front-channel logout depends on browser cookies, so test with third-party cookie restrictions.
