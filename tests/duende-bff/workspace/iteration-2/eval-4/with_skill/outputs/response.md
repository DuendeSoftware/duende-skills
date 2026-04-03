The root cause is almost certainly the **missing `X-CSRF: 1` header** in your `fetch()` calls.

BFF enforces anti-forgery protection on all API endpoints decorated with `.AsBffApiEndpoint()` (or the `[BffApi]` attribute). Every `fetch()` call to a BFF API endpoint **must** include the `X-CSRF: 1` header. Without it, BFF returns `401 Unauthorized` — even if the user is fully authenticated and has a valid session.

The `/bff/user` endpoint works because it's a management endpoint, not a protected API endpoint. But your custom API endpoints require the anti-forgery header.

Here's a fetch wrapper that automatically handles this:

```javascript
// bffFetch.js — Centralized fetch wrapper for BFF API calls
async function bffFetch(url, options = {}) {
    const response = await fetch(url, {
        ...options,
        headers: {
            'X-CSRF': '1',    // Required anti-forgery header
            ...options.headers,
        },
    });

    if (response.status === 401) {
        // Session expired — redirect to BFF login
        // IMPORTANT: /bff/login must be a browser navigation, NOT a fetch call
        window.location.href = `/bff/login?returnUrl=${encodeURIComponent(window.location.pathname)}`;
        return;
    }

    return response;
}

// Usage examples:
const orders = await bffFetch('/api/orders').then(r => r.json());
const result = await bffFetch('/api/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'New Order' }),
}).then(r => r.json());
```

Important notes:

1. **`/bff/login` and `/bff/logout` must be browser navigations** (`window.location.href`), not `fetch()` calls. These endpoints trigger OIDC redirects that require a full page navigation.

2. **Centralize the header injection** — Don't add `X-CSRF: 1` to every individual call site. Use the wrapper above or an Axios interceptor to ensure it's never forgotten.

3. **401 handling redirects to login** — When BFF returns 401 from an API endpoint, it means the session has expired. The SPA should redirect to `/bff/login` to re-authenticate.

4. **The `X-CSRF` header value doesn't matter** — The header just needs to be present. Setting it to `'1'` is the convention, but any value works. Its purpose is to trigger a CORS preflight, which prevents cross-origin CSRF attacks.
