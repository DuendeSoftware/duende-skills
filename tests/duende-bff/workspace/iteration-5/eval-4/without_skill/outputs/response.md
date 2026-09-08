# Debugging 401s from your BFF API calls

If `/bff/user` works but your API `fetch()` calls return `401`, the session itself is fine — something about how those particular requests are made is different. A few things to check, most-likely first.

## 1. Are you sending the session cookie?

The most common cause is that `fetch` isn't including credentials. By default `fetch` only sends cookies for same-origin requests, and even then some setups need it made explicit. If your SPA is served from a different origin than the BFF, the cookie won't be attached at all and you'll get 401s.

```javascript
const res = await fetch('/api/orders', {
    credentials: 'include',   // send the auth cookie
});
```

If `/bff/user` is working, you may already be doing this for that call but not for your API calls — make sure every API request includes it.

## 2. Anti-forgery / CSRF header

BFF-style hosts often require a custom header on API calls as a CSRF safeguard. If your API endpoints are protected that way, requests without the header are rejected. Make sure your API requests send whatever header your `/bff/user` request sends.

## 3. Centralize it in a wrapper

Rather than remembering these options on every call, wrap `fetch`:

```javascript
async function api(url, options = {}) {
    const res = await fetch(url, {
        ...options,
        credentials: 'include',
        headers: { ...options.headers },
    });

    if (res.status === 401) {
        // not/no longer authenticated → send them to log in
        window.location.href = '/bff/login';
        return;
    }
    return res;
}

const orders = await api('/api/orders').then(r => r.json());
```

## 4. CORS (if cross-origin)

If the SPA and BFF are on different origins, the server must return `Access-Control-Allow-Credentials: true` and a specific `Access-Control-Allow-Origin` (not `*`), otherwise the browser drops the credentialed response and you see failures.

Start with `credentials: 'include'` on all API calls — that resolves the majority of "authenticated but still 401" cases — and confirm any required anti-forgery header is present.
