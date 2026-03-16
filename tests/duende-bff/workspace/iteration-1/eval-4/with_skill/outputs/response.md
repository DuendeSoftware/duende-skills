# SPA 401 Errors: Missing X-CSRF Header

## Root Cause

The `X-CSRF: 1` header is missing from your `fetch()` calls. BFF enforces a custom anti-forgery header on every protected endpoint via `.AsBffApiEndpoint()`. Without this header, **all** API requests return 401, even for authenticated users.

The header value is irrelevant — its presence triggers a CORS preflight for cross-origin requests, effectively preventing CSRF attacks.

## Fix: Fetch Wrapper with CSRF Header

Create a centralized fetch wrapper that automatically includes the header:

```javascript
// bffFetch.js
async function bffFetch(url, options = {}) {
    const response = await fetch(url, {
        ...options,
        headers: {
            'X-CSRF': '1',
            ...options.headers,
        },
    });

    if (response.status === 401) {
        // Session expired — redirect to BFF login endpoint
        window.location.href = `/bff/login?returnUrl=${encodeURIComponent(window.location.pathname)}`;
        return;
    }

    return response;
}

// Usage
const orders = await bffFetch('/api/orders').then(r => r.json());
```

## Login/Logout: Browser Navigation Only

`/bff/login` and `/bff/logout` **must be browser navigations** (`window.location.href`), not `fetch()` calls. They trigger OIDC redirects that require full-page navigation:

```javascript
// Login — browser navigation
window.location.href = '/bff/login';

// Logout — must include sid from /bff/user response
const user = await bffFetch('/bff/user').then(r => r.json());
const sid = user.find(c => c.type === 'sid')?.value;
window.location.href = `/bff/logout?sid=${sid}`;
```

## Why /bff/user Works

`/bff/user` works because it's the session check endpoint. But your API endpoints return 401 because they have the anti-forgery check enabled via `.AsBffApiEndpoint()` — and your `fetch()` calls aren't sending the required `X-CSRF: 1` header.
