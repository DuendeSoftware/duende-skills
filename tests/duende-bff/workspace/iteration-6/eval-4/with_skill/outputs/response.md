# Why fetch() gets 401

The most likely cause: **the `X-CSRF: 1` header is missing**. `/bff/user` works because it's a management endpoint, but BFF API endpoints (`AsBffApiEndpoint()` / `MapRemoteBffApiEndpoint`) require the anti-forgery header; without it BFF returns 401. (Also check the session hasn't expired; `/bff/user` returning 401 means not logged in.)

```javascript
// ❌ Missing header -> 401
const data = await fetch('/api/orders').then(r => r.json());

// ✅ Wrapper that always adds it and handles expiry
async function bffFetch(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: { 'X-CSRF': '1', ...options.headers },
  });

  if (response.status === 401) {
    // Session expired: login is a browser navigation, not fetch
    window.location.href = `/bff/login?returnUrl=${encodeURIComponent(window.location.pathname)}`;
    return;
  }
  return response;
}

const data = await bffFetch('/api/orders').then(r => r.json());
```

Notes: the value is irrelevant, presence is enough (header name/value come from `AntiForgeryHeaderName`/`AntiForgeryHeaderValue`). Login/logout must be navigations; logout needs `?sid=` from `/bff/user`. Also, calls to a frontend's remote APIs without the header return 401 from 4.0.4/4.1.3/4.2.1/4.3.1.
