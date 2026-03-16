# SPA Getting 401 Errors on BFF API Calls

## Likely Cause

If your users are authenticated and can see data on `/bff/user` but get 401 errors on API endpoints, the most likely cause is the missing CSRF protection header. Duende BFF requires an `X-CSRF: 1` header on all API requests for anti-forgery protection.

## Fix

Add the `X-CSRF: 1` header to your fetch calls:

```javascript
async function apiFetch(url, options = {}) {
    const response = await fetch(url, {
        ...options,
        headers: {
            'X-CSRF': '1',
            ...options.headers,
        },
    });

    if (response.status === 401) {
        // Redirect to login
        window.location.href = '/bff/login';
        return;
    }

    return response;
}
```

Make sure to use this wrapper for all your API calls. The login and logout endpoints (`/bff/login` and `/bff/logout`) should be navigated to via `window.location.href`, not via fetch, since they trigger full page redirects.
