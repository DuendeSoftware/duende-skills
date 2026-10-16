# 401s from fetch()

`/bff/user` works because it's a management endpoint. Your API endpoints are BFF API endpoints, which require the anti-forgery header `X-CSRF: 1`. Without it, BFF rejects the call with 401. Also, `fetch` must send the cookie.

```js
const res = await fetch("/api/orders", {
  credentials: "include",           // same-origin is default; include if cross-origin
  headers: { "X-CSRF": "1" }
});

if (res.status === 401) {
  window.location.href = "/bff/login?returnUrl=" + encodeURIComponent(location.pathname);
} else if (res.ok) {
  const data = await res.json();
}
```

Also check: the SPA is served from the same site as the BFF; the session hasn't expired (call `/bff/user` and look at 401); the header name matches your configured `AntiForgeryHeaderName`/value. For POST etc. same header applies. A wrapper:

```js
const api = (url, opts = {}) => fetch(url, { ...opts, headers: { "X-CSRF": "1", ...opts.headers }});
```
