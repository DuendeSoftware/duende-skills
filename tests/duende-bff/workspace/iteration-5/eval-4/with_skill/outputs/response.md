# Why your BFF API calls return 401 (and how to fix it)

## Root cause: the missing `X-CSRF: 1` header

Your users are authenticated — that's why `/bff/user` returns their claims. The reason `fetch()` calls to your BFF **API** endpoints get a `401` is that they're missing the BFF anti-forgery header:

```
X-CSRF: 1
```

Every BFF API endpoint (anything marked with `.AsBffApiEndpoint()`, a `[BffApi]` controller, or a `MapRemoteBffApiEndpoint`) requires this header. Its presence is what BFF checks — the value is irrelevant, `1` is conventional. This requirement is what forces a CORS preflight for cross-origin requests and is the mechanism that blocks CSRF. Your `/bff/user` call almost certainly already sends it (or you'd get 401 there too); your API `fetch` calls don't.

## The fix: a fetch wrapper that always sends the header

Don't add the header at every call site — centralize it:

```javascript
// bffFetch.js
export async function bffFetch(url, options = {}) {
    const response = await fetch(url, {
        ...options,
        headers: {
            'X-CSRF': '1',            // ✅ required anti-forgery header
            ...options.headers,
        },
    });

    // Centralized session-expiry handling
    if (response.status === 401) {
        // Session expired → send the browser to the BFF login endpoint
        window.location.href =
            `/bff/login?returnUrl=${encodeURIComponent(window.location.pathname)}`;
        return; // navigation in progress
    }

    return response;
}

// Usage — no per-call header needed:
const orders = await bffFetch('/api/orders').then(r => r.json());
```

## Important: login and logout are navigations, not `fetch`

The `/bff/login` and `/bff/logout` endpoints perform OIDC redirects to and from your IdP. They **must** be triggered as full browser navigations — never via `fetch`/XHR, which cannot follow the cross-document redirects:

```javascript
// ✅ Login — browser navigation
window.location.href = '/bff/login';

// ✅ Logout — browser navigation; include the sid claim from /bff/user
const user = await bffFetch('/bff/user').then(r => r.json());
const sid  = user.find(c => c.type === 'sid')?.value;
window.location.href = `/bff/logout?sid=${sid}`;
```

## Summary

- **Cause:** API `fetch` calls lack `X-CSRF: 1` → BFF returns 401.
- **Fix:** wrap `fetch` so the header is always attached.
- **Bonus:** handle `401` centrally by redirecting to `/bff/login`.
- **Don't** call `/bff/login` or `/bff/logout` via `fetch` — use `window.location.href`.
