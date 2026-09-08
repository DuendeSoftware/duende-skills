# `IAuthorizationParametersMessageStore` in v8: use PAR

You're right — **`IAuthorizationParametersMessageStore` was removed in v8**. It previously existed to stash large or sensitive authorization request parameters server-side (returning a small reference on the redirect). v8 drops the custom interface in favor of the standardized OAuth mechanism for exactly this problem: **PAR (Pushed Authorization Requests, RFC 9126)**.

## Why PAR is the replacement

With PAR, the client sends the authorization parameters directly to a dedicated **PAR endpoint** (`/connect/par`) in a back-channel POST *before* redirecting the user. The server stores them and returns a `request_uri`. The browser redirect then carries only that short `request_uri` instead of a long query string. This solves the same "authorization request is too big / shouldn't be in the URL" problem the message store was working around — but as a first-class, interoperable protocol feature.

## What to do instead

1. **Remove** your `IAuthorizationParametersMessageStore` implementation and its DI registration. Do **not** try to reimplement it — the interface no longer exists in v8.
2. **Enable PAR on the relevant clients.** Configure clients to use pushed authorization requests, for example by requiring it:

   ```csharp
   new Client
   {
       ClientId = "web",
       // ... existing config ...
       RequirePushedAuthorization = true   // enforce PAR for this client
   }
   ```

   This corresponds to the client metadata flag `require_pushed_authorization_requests`.
3. **Update the client application** to POST its authorization parameters to the PAR endpoint (`/connect/par`) and then redirect using the returned `request_uri`. Most modern OIDC client libraries support PAR natively.

## Summary

- `IAuthorizationParametersMessageStore` is gone in v8 — don't reimplement it.
- The replacement is **PAR**: clients push parameters to the PAR endpoint and redirect with a `request_uri`.
- Turn it on per client via `RequirePushedAuthorization` / `require_pushed_authorization_requests`, and update the client to call the PAR endpoint.
