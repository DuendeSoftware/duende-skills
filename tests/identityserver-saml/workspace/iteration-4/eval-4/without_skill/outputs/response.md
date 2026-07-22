# SAML Single Logout (SLO) in Duende IdentityServer

## What Single Logout Is

SAML Single Logout (SLO) is a protocol that allows a user to log out of all service providers simultaneously through a single action at the Identity Provider (or from any participating SP). When a logout is initiated, the IdP sends `LogoutRequest` messages to all SPs that have an active session for the user, and collects `LogoutResponse` confirmations before completing the logout.

There are two bindings for SLO:
- **HTTP-Redirect** — the browser is redirected through each SP's SLO endpoint in turn.
- **HTTP-POST** — a form POST is used for each SP.
- **SOAP (back-channel)** — the IdP calls each SP's SLO endpoint directly, without involving the browser. More reliable but requires the SP to expose a reachable SOAP endpoint.

---

## How SLO Works in Duende IdentityServer (SAML Plugin)

1. **User initiates logout** at the IdP (or an SP sends a `LogoutRequest` to the IdP's SLO endpoint).
2. The IdP identifies all SPs with an active SAML session for that user.
3. The IdP sends a `LogoutRequest` to each SP's registered Single Logout Service (SLS) URL.
4. Each SP terminates the local session and replies with a `LogoutResponse`.
5. Once all SPs have responded (or timed out), the IdP completes its own session termination and redirects the user to the post-logout page.

Duende IdentityServer integrates SAML SLO with its own session management so that logging out via OIDC also triggers SAML SLO (and vice-versa).

---

## What You Need to Configure on the SP Registration

### Minimum: Register the SP's SLO Endpoint

Add a `SingleLogoutServices` entry on the `ServiceProvider` model:

```csharp
new ServiceProvider
{
    EntityId = "https://crm.contoso.com",
    AssertionConsumerServices =
    {
        new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/acs")
    },
    SingleLogoutServices =
    {
        new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/slo")
    }
}
```

- `SamlConstants.BindingTypes.HttpPost` — use HTTP-POST for the logout message.
- `SamlConstants.BindingTypes.HttpRedirect` — use HTTP-Redirect (browser redirect chain).

### Optional: Require Signed Logout Requests/Responses

For security, especially in production, configure the SP's signing certificate so IdentityServer can verify that logout requests actually come from the SP:

```csharp
new ServiceProvider
{
    EntityId = "https://crm.contoso.com",
    // ...
    SingleLogoutServices =
    {
        new Service(SamlConstants.BindingTypes.HttpPost, "https://crm.contoso.com/saml/slo")
    },
    // Public key certificate of the SP (for verifying signatures on inbound LogoutRequests)
    SigningCertificates =
    {
        new X509Certificate2(Convert.FromBase64String("MII...SP cert base64..."))
    }
}
```

---

## IdP-Initiated vs SP-Initiated Logout

| Scenario | Who starts it | Flow |
|----------|--------------|------|
| **IdP-initiated** | User clicks logout at IdentityServer | IdP fans out `LogoutRequest` to all SPs |
| **SP-initiated** | User clicks logout at the SP | SP sends `LogoutRequest` to IdP SLO endpoint; IdP fans out to remaining SPs |

IdentityServer's SAML plugin handles both scenarios. For SP-initiated logout, the IdP's SLO endpoint URL is published in the IdP metadata:

```
https://<your-idp>/saml/slo
```

The SP should be configured to POST or redirect `LogoutRequest` messages to this URL.

---

## Configuration Checklist

- [ ] SP registration includes `SingleLogoutServices` with the correct binding and URL.
- [ ] SP's SLO endpoint is reachable by the browser (HTTP-POST/Redirect) or by the IdP server (SOAP back-channel).
- [ ] If signatures are required, SP's signing certificate is registered on the `ServiceProvider` model.
- [ ] The SP's own software is configured to handle incoming `LogoutRequest` from the IdP and reply with a `LogoutResponse`.
- [ ] The SP's metadata references the IdP's SLO endpoint (`https://<your-idp>/saml/slo`).

---

## Debugging SLO

If logout doesn't propagate correctly:

1. **Check IdP logs** — Duende IdentityServer logs SAML SLO activity at `Debug` level under the `Duende.IdentityServer.Saml` category.
2. **Decode the LogoutRequest/Response** — base64-decode and inspect the XML to verify `SessionIndex` and `NameID` match the established session.
3. **Verify binding** — confirm the binding configured in the SP registration matches what the SP actually listens on.
4. **Check session tracking** — SAML SLO relies on `SessionIndex` being tracked. Ensure the IdP is persisting session grants (not using pure in-memory stores that don't survive restart).

---

## Summary

SLO requires minimal additional configuration beyond adding `SingleLogoutServices` to each SP registration. The SAML plugin handles the protocol orchestration; your responsibility is to ensure each SP's SLO endpoint is registered correctly and that the SP software is prepared to receive and respond to `LogoutRequest` messages from the IdP.
