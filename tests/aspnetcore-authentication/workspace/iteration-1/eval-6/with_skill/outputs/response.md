# Sign-Out Endpoint

Here's how to implement proper sign-out from both the local cookie session and IdentityServer:

```csharp
app.MapGet("/logout", async (HttpContext ctx) =>
{
    // 1. Clear the local authentication cookie
    await ctx.SignOutAsync("Cookies");

    // 2. Redirect to IdentityServer's end_session endpoint
    await ctx.SignOutAsync("oidc");
});
```

## The Sign-Out Flow

1. **`SignOutAsync("Cookies")`** — Deletes the local authentication cookie, ending the user's session in your app.
2. **`SignOutAsync("oidc")`** — Triggers the OIDC handler to redirect the browser to IdentityServer's `/connect/endsession` endpoint.
3. **IdentityServer clears its session** — The user's session at the IdP is terminated.
4. **Back-channel/front-channel logout** — IdentityServer notifies other relying party applications about the logout.
5. **Redirect to PostLogoutRedirectUri** — IdentityServer redirects the user back to your app's configured post-logout URI.

**Important:** If you only call `SignOutAsync("Cookies")` without `SignOutAsync("oidc")`, the IdentityServer session remains active. On the next authentication challenge, the user will be silently re-authenticated without seeing a login prompt.
