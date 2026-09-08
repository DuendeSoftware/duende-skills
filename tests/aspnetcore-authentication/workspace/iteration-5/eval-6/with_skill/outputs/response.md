A correct sign-out has to clear **two** sessions: the local cookie in your app, and the session held by IdentityServer. Signing out of only the cookie leaves the IdP session alive, so the next challenge silently logs the user straight back in.

## The endpoint

```csharp
var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/logout", async (HttpContext ctx) =>
{
    // 1. Clear the local authentication cookie (ends the app session)
    await ctx.SignOutAsync("Cookies");

    // 2. Sign out of the OIDC scheme -> redirects to IdentityServer's
    //    end session endpoint to terminate the IdP session
    await ctx.SignOutAsync("oidc");
})
.RequireAuthorization(); // only an authenticated user should be logging out

app.Run();
```

Both calls in a single request work because `SignOutAsync("Cookies")` writes the cookie-deletion into the response, and `SignOutAsync("oidc")` then issues the redirect to IdentityServer.

To control where the user lands afterward, set the post-logout redirect (registered as a valid `PostLogoutRedirectUri` on the client in IdentityServer):

```csharp
await ctx.SignOutAsync("oidc", new AuthenticationProperties
{
    RedirectUri = "/"
});
```

## The full sign-out flow

```
1. GET /logout
2. SignOutAsync("Cookies")   -> deletes the local auth cookie (app session gone)
3. SignOutAsync("oidc")      -> OIDC handler redirects the browser to
                                https://identity.example.com/connect/endsession
                                (with id_token_hint + post_logout_redirect_uri)
4. IdentityServer ends its own session (clears its auth cookie)
5. IdentityServer performs front-channel / back-channel logout to notify
   any other apps sharing that session
6. IdentityServer redirects back to your PostLogoutRedirectUri
```

### Why both are required

- `SignOutAsync("Cookies")` alone → app session cleared, but IdentityServer still thinks the user is logged in. The next `[Authorize]` challenge → `/connect/authorize` → IdentityServer sees its live session → issues a new token **without prompting** → user appears "never logged out."
- `SignOutAsync("oidc")` alone → IdP session ended, but your app's cookie lingers until it expires.

You need both to fully end the session. The `id_token_hint` (available because tokens were saved) lets IdentityServer skip the logout confirmation prompt and honor your post-logout redirect.
