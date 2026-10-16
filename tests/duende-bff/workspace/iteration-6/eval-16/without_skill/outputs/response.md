In recent 4.x releases BFF stopped forwarding the browser's `Cookie` header to upstream APIs by default (security hardening: the BFF session cookie should never leak to the remote API). Remote APIs should authenticate with the bearer access token BFF attaches.

Fix:
- Make sure the endpoint uses `.WithAccessToken(RequiredTokenType.User)` and the API validates JWT bearer tokens, not cookies.
- If you truly need a cookie upstream, add an explicit YARP transform: `builder.WithTransformRequestHeader("Cookie", "...")` or `context.AddRequestHeaderRemove`/custom transform, forwarding only the specific cookie you need — rather than the whole session cookie.
- Verify the 401s aren't because the API expected cookie auth; switch it to bearer.
I'm not certain of the exact option name for restoring old behavior.
