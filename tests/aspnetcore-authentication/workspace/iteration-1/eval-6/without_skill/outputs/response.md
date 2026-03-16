# Adding a Logout Endpoint

Here's how to implement sign-out:

```csharp
var builder = WebApplication.CreateBuilder(args);

// ... authentication setup ...

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.MapGet("/logout", async (HttpContext ctx) =>
{
    await ctx.SignOutAsync("Cookies");
    await ctx.SignOutAsync("oidc");
});

app.Run();
```

## Sign-Out Flow

1. The user navigates to `/logout`
2. `SignOutAsync("Cookies")` clears the local authentication cookie
3. `SignOutAsync("oidc")` triggers the OIDC handler to redirect to the identity provider's end session endpoint
4. The identity provider clears its own session
5. The user is redirected back to a configured post-logout redirect URI

It's important to sign out of both schemes. If you only clear the local cookie, the user will still have an active session at the identity provider and could be silently re-authenticated on the next request.
