# Cookie header removal (4.3.1)

**What changed:** 4.3.1 (and 4.2.1, 4.1.3, 4.0.4, plus 3.x/2.x patches) are security fixes. The BFF now strips the browser's `Cookie` header on **all YARP routes**, as `MapRemoteBffApiEndpoint` always did. The BFF session cookie must never reach a remote API; the API authenticates with the access token BFF attaches.

Also in the same releases, calls to a **frontend's remote APIs** must include the anti-forgery header (`X-CSRF: 1`); otherwise BFF returns **401** (and logs a warning) *before* attaching a token. That likely explains your 401s.

**How to handle it:**
1. Make the browser/SPA send `X-CSRF: 1` on calls to those remote APIs:
```js
fetch('/api/remote', { headers: { 'X-CSRF': '1' } });
```
(Header name/value come from `AntiForgeryHeaderName`/`AntiForgeryHeaderValue`. There's no per-API opt-out; `BffOptions.DisableAntiForgeryCheck` — a delegate — can conditionally disable it.)
2. Make the remote API validate the bearer token (`.WithAccessToken(RequiredTokenType.User)` / YARP `WithAccessToken(TokenType.User)`) instead of cookies.
3. If you really need a specific cookie upstream, add a transform registered **after** `AddBffExtensions` (e.g. `.AddTransforms(...)` on the returned `IReverseProxyBuilder`) setting just that cookie — don't copy the browser's cookies.
4. Opt-out (not recommended; leaks the session cookie to every YARP API):
```csharp
builder.Services.AddBff(o => o.RemoveCookieHeaderFromYarpRequests = false);
```
then remove per route with `.WithTransformRequestHeaderRemove("Cookie")`.
