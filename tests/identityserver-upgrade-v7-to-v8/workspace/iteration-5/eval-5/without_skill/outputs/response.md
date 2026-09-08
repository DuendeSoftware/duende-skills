# Replacing `IAuthorizationParametersMessageStore`

I don't have v8's exact removal list memorized, but I'll reason from what this interface did and the standard OAuth mechanisms that address the same need. Verify the specifics in Duende's 8.0 upgrade guide.

## What that interface was for

`IAuthorizationParametersMessageStore` let IdentityServer persist authorization request parameters server-side and hand back a small reference, instead of carrying a very large (or sensitive) set of parameters through the browser redirect URL. So the real problem it solved was: "the authorization request is too big or shouldn't live in the query string."

## The modern, standards-based replacement: PAR

OAuth solved this at the protocol level with **PAR — Pushed Authorization Requests (RFC 9126)**. Instead of stashing parameters in a server-side store keyed by a custom reference, the client makes a direct back-channel POST of all authorization parameters to a **PAR endpoint** (typically `/connect/par`). The server returns a `request_uri`, and the browser redirect then only needs to carry that short `request_uri`. This is almost certainly the intended replacement in v8, since it addresses the identical concern using a first-class protocol feature.

(A related option for the "large/signed request" case is JAR — passing a signed `request`/`request_uri` object — but PAR is the direct fit for pushing parameters server-side.)

## What to do

1. Drop the old `IAuthorizationParametersMessageStore` implementation and registration — since the interface no longer exists, there's nothing to reimplement.
2. Turn on PAR for the affected clients. In OIDC/OAuth terms this is the client setting **`require_pushed_authorization_requests`**, and IdentityServer exposes a corresponding client option to require it.
3. Update the client app to call the PAR endpoint first and redirect with the returned `request_uri`. Most current OIDC libraries support PAR out of the box.

I'd confirm the exact IdentityServer client property name and endpoint route in the official v8 docs, but PAR is the mechanism you want.
