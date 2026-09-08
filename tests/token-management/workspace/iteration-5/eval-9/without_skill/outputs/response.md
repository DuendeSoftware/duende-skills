# Blazor Server 401s and the HttpContext Problem

## Why it happens

Blazor Server runs your components inside a **circuit** — a persistent SignalR connection between the browser and server. `HttpContext` only exists for the initial HTTP request that establishes the circuit. After that, component code runs over the SignalR channel where there is **no active HTTP request and no `HttpContext`**. Anything that relies on `IHttpContextAccessor.HttpContext` (including the cookie-based access-token lookup) returns `null` or stale data once the circuit is live.

That's why your API calls eventually 401: the access token stored at login expires, and the component has no `HttpContext` to read or refresh it from, so it keeps sending an expired token.

## The approach that works

You need tokens stored somewhere the circuit *can* reach — independent of `HttpContext` — and refreshed when they expire:

1. **Capture the tokens at login.** During the OIDC sign-in, in the `OnTokenValidated` event (where `HttpContext` still exists), read the access and refresh tokens and save them to a server-side store keyed by the user's `sub`.

   ```csharp
   options.SaveTokens = true;
   options.Scope.Add("offline_access"); // so you get a refresh token

   options.Events.OnTokenValidated = async ctx =>
   {
       var accessToken  = ctx.TokenEndpointResponse?.AccessToken;
       var refreshToken = ctx.TokenEndpointResponse?.RefreshToken;
       // persist these for ctx.Principal (e.g. to a DB keyed by sub)
   };
   ```

2. **Store tokens server-side**, e.g. in a database or a distributed cache, rather than only in the auth cookie. A scoped service can then read them inside the circuit without touching `HttpContext`.

3. **Refresh proactively.** When the stored access token is near expiry, use the refresh token to get a new one (call the token endpoint) and update the store. Make sure `offline_access` is requested so a refresh token is issued.

4. **Avoid `HttpContext` in components.** Don't call `HttpContext.GetUserAccessTokenAsync()` from a component — inject your server-side token service instead.

## Summary

- Root cause: `HttpContext` is unavailable inside a Blazor Server circuit after the initial request, so cookie-based token reads/refreshes fail and expired tokens cause 401s.
- Fix: capture tokens during OIDC login (`OnTokenValidated`), persist them in a server-side store keyed by the user, refresh them with the refresh token, and read them through a scoped service instead of `HttpContext`.

If you're using Duende's access token management, check its docs for a Blazor-specific integration that lets you plug in a custom server-side token store so the refresh/caching logic is handled for you rather than hand-rolling step 3.
