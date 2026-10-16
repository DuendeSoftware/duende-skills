# prompt=none and the error page

Per OIDC Core, when `prompt=none` is sent and the server needs interaction, it must not show UI. It returns the error to the client's `redirect_uri` — `login_required`, `consent_required`, or `interaction_required`. This is by spec, which is why your error page never shows.

## Which go where
**Returned to client redirect_uri (once client_id and redirect_uri validated):** protocol errors such as `invalid_request`, `invalid_scope`, `unauthorized_client`, `unsupported_response_type`, `access_denied`, `login_required`, `consent_required`, `interaction_required`, `account_selection_required`. The response mode (query/fragment/form_post) is used.

**Shown on IdentityServer's error page:** errors where it can't trust the client/redirect – unknown `client_id`, invalid/unregistered `redirect_uri`, missing parameters needed to identify the client, malformed request objects, and unexpected exceptions. Redirecting there would risk an open redirect.

## Can you change it?
Not for the spec-mandated cases – the client needs `login_required` so it can fall back to interactive login (silent renew etc.). You can control the error page itself:

```csharp
options.UserInteraction.ErrorUrl = "/Error";
options.UserInteraction.ErrorIdParameter = "errorId";
```
and retrieve details using `IIdentityServerInteractionService.GetErrorContextAsync(errorId)`. To see what happened server-side, enable logging for `Duende.IdentityServer` at Debug. If you want less client-facing leakage, you could customise via `ICustomAuthorizeRequestValidator`, but I'd leave the spec behaviour alone.
