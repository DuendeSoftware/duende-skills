# Missing X-CSRF Header in SPA Fetch Calls

## Root Cause

The BFF enforces an anti-forgery header (`X-CSRF: 1`) on every protected API endpoint. When your SPA calls BFF endpoints with `fetch()` without this header, the BFF returns 401 — even if the user is authenticated. The `/bff/user` endpoint works because it's a management endpoint with different rules.

## Fix: Add X-CSRF Header to All Fetch Calls

Create a centralized fetch wrapper that automatically includes the header:

```javascript
// bffFetch.js — centralized BFF fetch wrapper
async function bffFetch(url, options = {}) {
    const response = await fetch(url, {
        ...options,
        headers: {
            'X-CSRF': '1',  // Required by BFF anti-forgery middleware
            ...options.headers,
        },
    });

    if (response.status === 401) {
        // Session expired — redirect to BFF login
        window.location.href = `/bff/login?returnUrl=${encodeURIComponent(window.location.pathname)}`;
        return;
    }

    return response;
}

// Usage in React components
const orders = await bffFetch('/api/orders').then(r => r.json());
```

## Important Notes

- **`/bff/login` and `/bff/logout` must be browser navigations** (`window.location.href`), not `fetch()` calls. These endpoints trigger OIDC redirects that can't work as AJAX requests.
- The header value `1` is a convention — the BFF only checks for the header's **presence**, not its value.
- Use the wrapper for all API calls (`/api/*`) but NOT for `/bff/login` or `/bff/logout`.

```javascript
// ✅ Login — browser navigation
window.location.href = '/bff/login';

// ✅ Logout — browser navigation with sid
const user = await bffFetch('/bff/user').then(r => r.json());
const sid = user.find(c => c.type === 'sid')?.value;
window.location.href = `/bff/logout?sid=${sid}`;

// ❌ This will NOT work
fetch('/bff/login'); // OIDC redirect can't happen in fetch
```
