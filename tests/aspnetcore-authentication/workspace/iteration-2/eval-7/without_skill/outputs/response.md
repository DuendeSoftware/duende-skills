# Authentication Cookie Too Large

## The Problem

With `SaveTokens = true`, the OIDC handler stores access, refresh, and ID tokens in the cookie, which can push it over the 4KB limit.

## Solutions

### 1. Reduce Claims

You can remove unnecessary claims to reduce cookie size. Use claim filtering options in the OIDC handler to exclude claims you don't need.

### 2. Store Session Server-Side

Instead of putting everything in the cookie, you can implement a server-side session store. ASP.NET Core provides an `ITicketStore` interface that you can implement to store the authentication ticket in a database or distributed cache. The cookie would then only contain a session identifier.

```csharp
.AddCookie("Cookies", options =>
{
    options.SessionStore = myTicketStoreImplementation;
});
```

### 3. Limit Token Storage

If you don't need all the tokens, consider setting `SaveTokens = false` and only storing what you need. However, this means you won't be able to use `GetTokenAsync()` to retrieve tokens later.

These approaches can be combined for the best result.
