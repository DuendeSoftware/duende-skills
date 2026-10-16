# `prompt=none`: which errors go to the client vs. the error page

## What's happening
With `prompt=none` the user can't be shown UI, so IdentityServer returns `login_required` (or `consent_required` / `interaction_required`) to the client's `redirect_uri` — as OIDC requires. Clients using `prompt=none` must handle `login_required` in their callback (e.g. fall back to an interactive login).

## Errors redirected to the client
A fixed set of "safe" codes is sent to the client's `redirect_uri` (using the request's response mode) with `error`, `error_description` and `state`:

- `login_required`
- `consent_required`
- `interaction_required`
- `account_selection_required`
- `access_denied`
- `temporarily_unavailable`
- `unmet_authentication_requirements` (RFC 9470 step-up)

## Errors shown on your error page
Everything else: `invalid_request`, `unauthorized_client`, `unsupported_response_type`, `invalid_scope`, `invalid_target`, `invalid_request_uri`, `invalid_request_object`, `request_uri_not_supported`, `server_error`, and any custom code. The request isn't trustworthy enough to redirect back to, so redirecting could become an open redirect.

## Can you change it?
**No — the set of safe codes isn't configurable.** What you can control:
- The error page itself:
```csharp
options.UserInteraction.ErrorUrl = "/Error";
options.UserInteraction.ErrorIdParameter = "errorId";
```
with `GetErrorContextAsync(errorId)` for details.
- A custom `AuthorizeInteractionResponseGenerator` can return an error by setting `InteractionResponse.Error` (and optionally `ErrorDescription`). It follows the same routing rule: a custom string shows the error page, while e.g. `unmet_authentication_requirements` goes to the client.

If you want the user to see something for `login_required`, handle it client-side in the callback (redirect to a normal login, or show your own message). Full server-side detail for any error is in the IdentityServer logs at `Debug` level.
