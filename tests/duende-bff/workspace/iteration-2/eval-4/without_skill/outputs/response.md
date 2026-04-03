If your users are authenticated (you can see data on /bff/user) but getting 401 errors on API endpoints, the issue is likely related to CSRF protection.

Duende BFF requires an anti-forgery header on API calls. You need to include a custom header in your fetch requests. Try adding an `X-CSRF` header:

```javascript
// Add the X-CSRF header to your fetch calls
async function fetchApi(url, options = {}) {
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

// Usage
const orders = await fetchApi('/api/orders').then(r => r.json());
```

The BFF pattern typically requires this anti-forgery header to prevent cross-site request forgery attacks. Without it, even authenticated requests will be rejected.

You should also make sure your login/logout flows use full page navigation rather than AJAX calls, since they involve redirects to the identity provider.
