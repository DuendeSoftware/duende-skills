# Sign-Out Endpoint

To sign out from both the local session and IdentityServer, create a logout endpoint:

```csharp
app.MapGet("/logout", async (HttpContext ctx) =>
{
    await ctx.SignOutAsync("Cookies");
    await ctx.SignOutAsync("oidc");
});
```

This first clears the local cookie, then triggers the OIDC sign-out flow which redirects to IdentityServer's end session endpoint. The user will be signed out of IdentityServer and redirected back to your app.
