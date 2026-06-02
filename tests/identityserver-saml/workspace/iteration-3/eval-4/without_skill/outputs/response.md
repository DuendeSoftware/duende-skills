# SAML Single Logout (SLO) in Duende IdentityServer

## Overview

Single Logout allows a user to log out from all connected service providers when they log out from one. In SAML, this is typically implemented using LogoutRequest and LogoutResponse messages.

## How It Works

1. User initiates logout at one SP
2. SP sends a SAML LogoutRequest to the IdP
3. IdP terminates the user's session
4. IdP sends LogoutRequest to all other SPs that have sessions
5. SPs respond with LogoutResponse
6. IdP sends final LogoutResponse to the originating SP

## Configuration

Configure the SLO endpoint on your service provider:

```csharp
new ServiceProvider
{
    EntityId = "https://sp.example.com",
    SingleLogoutService = new Endpoint
    {
        Location = "https://sp.example.com/saml/slo",
        Binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
    }
}
```

## Considerations

- SLO can be unreliable in practice because it depends on all SPs being reachable
- Some SPs may not support SLO
- Browser-based implementations may be affected by cookie policies
- Consider session timeouts as a fallback mechanism
