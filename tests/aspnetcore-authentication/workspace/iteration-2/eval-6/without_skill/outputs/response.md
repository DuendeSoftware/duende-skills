# Sign-Out Endpoint

To properly sign out from both your app and the identity provider, you need to sign out of both schemes:

```csharp
app.MapGet("/logout", async (HttpContext ctx) =>
{
    await ctx.SignOutAsync("Cookies");
    await ctx.SignOutAsync("oidc");
});
```

## How It Works

1. `SignOutAsync("Cookies")` clears the local authentication cookie
2. `SignOutAsync("oidc")` redirects to the identity provider's end session endpoint

This ensures the user is logged out of both your application and the identity provider. If you only clear the cookie, the user's session on the identity provider remains active and they could be automatically re-authenticated on the next request.
