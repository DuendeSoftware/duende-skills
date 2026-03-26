# 401 Errors on BFF API Calls

If you're getting 401 errors when calling BFF endpoints despite being authenticated, the issue is likely that you're missing the anti-forgery header.

Duende BFF requires a CSRF protection header on API calls. Add the `X-CSRF: 1` header to your fetch requests:

```javascript
const response = await fetch('/api/orders', {
    headers: {
        'X-CSRF': '1'
    }
});
```

You can create a wrapper function:

```javascript
function apiFetch(url, options = {}) {
    return fetch(url, {
        ...options,
        headers: {
            'X-CSRF': '1',
            ...options.headers,
        },
    });
}
```

If you get a 401 response, the user's session may have expired and they need to log in again.
