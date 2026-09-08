To fully sign a user out of an OIDC-authenticated app, you have to end **both** sessions: the local cookie session in your app and the session that IdentityServer keeps. If you only clear the local cookie, IdentityServer still considers the user logged in and will silently re-authenticate them on the next login challenge.

## The `/logout` endpoint

```csharp
var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/logout", async (HttpContext context) =>
{
    // Clear the local cookie session
    await context.SignOutAsync("Cookies");

    // Sign out of OIDC -> redirects to IdentityServer's end-session endpoint
    await context.SignOutAsync("oidc", new AuthenticationProperties
    {
        RedirectUri = "/"
    });
})
.RequireAuthorization();

app.Run();
```

(If you used the default scheme names, `CookieAuthenticationDefaults.AuthenticationScheme` and `OpenIdConnectDefaults.AuthenticationScheme` are equivalent to `"Cookies"` and `"oidc"`.)

## Explanation of the sign-out flow

1. **`SignOutAsync("Cookies")`** deletes your application's authentication cookie, so the local session is gone.
2. **`SignOutAsync("oidc")`** invokes the OpenID Connect handler's sign-out logic. It builds a request to IdentityServer's **end session endpoint** (`/connect/endsession`), passing the `id_token_hint` and a `post_logout_redirect_uri`.
3. The browser is redirected to IdentityServer, which **clears its own session cookie**.
4. IdentityServer performs any **front-channel or back-channel logout** notifications to other applications that shared the session (single sign-out).
5. IdentityServer redirects the browser back to your app's registered post-logout URL (here, `/`).

### Why both calls are necessary

- Cookie-only sign-out leaves the IdentityServer session intact → the user is re-logged-in automatically on the next challenge.
- OIDC sign-out ends the IdP session and triggers single sign-out across apps.

Make sure the `post_logout_redirect_uri` you use is registered as an allowed value on the client in IdentityServer, otherwise the redirect back will be rejected.
