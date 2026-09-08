# Implementing SAML Single Logout (SLO)

SAML Single Logout lets a user log out of the IdP and all the service providers they signed into during their session, in one action. There are two flavors defined by the SAML spec, and how you configure it depends on which your SPs support.

## Front-channel vs back-channel

- **Front-channel (via the browser)**: The IdP notifies each SP by sending `LogoutRequest` messages through the user's browser, typically using redirects or hidden iframes. This is the most widely supported approach because the SP just needs a public SLO endpoint.
- **Back-channel (server-to-server)**: The IdP calls each SP directly over SOAP. More reliable but far less commonly implemented.

Most deployments use front-channel SLO.

## Configuration on the SP registration

For each service provider, you need to tell the IdP where to send logout messages — the SP's Single Logout Service URL and the binding it expects:

```csharp
new ServiceProvider
{
    EntityId = "https://sp.example.com",
    SingleLogoutServiceUrl = "https://sp.example.com/saml/slo",
    // binding is usually HTTP-Redirect or HTTP-POST
}
```

You'll also typically need:

- The SP's signing certificate, so the IdP can verify signed `LogoutRequest`/`LogoutResponse` messages, and its own certificate to sign outgoing ones.
- Matching NameID and SessionIndex so the SP can identify which session to terminate.

## Practical considerations

1. **Reliability**: Front-channel SLO depends on the browser reaching every SP. If one SP is unreachable or slow, the logout may not fully complete for that SP. Design for this — don't assume every SP session is guaranteed to be terminated.
2. **Session tracking**: The IdP must track which SPs the user logged into so it knows who to notify at logout.
3. **Signing**: LogoutRequest and LogoutResponse messages are normally signed; make sure certificates line up on both sides.
4. **Timeouts**: Give the logout flow time to notify all SPs before completing.

## Recommendation

Confirm the exact configuration property names and SLO options against your SAML library's documentation, and test the round-trip with each SP, since SLO interoperability is notoriously finicky between different SAML implementations.
