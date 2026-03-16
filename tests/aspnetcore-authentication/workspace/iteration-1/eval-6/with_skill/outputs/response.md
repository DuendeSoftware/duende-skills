# Sign-Out Endpoint

Here's how to add a `/logout` endpoint that properly signs out from both the local cookie session and IdentityServer:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    // ... OIDC configuration ...
});

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

// Sign-out endpoint
app.MapGet("/logout", async (HttpContext ctx) =>
{
    // Step 1: Clear the local cookie session
    await ctx.SignOutAsync("Cookies");

    // Step 2: Redirect to IdentityServer's end session endpoint
    await ctx.SignOutAsync("oidc");
});

app.Run();
```

## The Sign-Out Flow

The full sign-out flow involves multiple steps:

```
1. User visits /logout
2. SignOutAsync("Cookies")       → Clears the local authentication cookie
3. SignOutAsync("oidc")          → Redirects to IdentityServer's /connect/endsession endpoint
4. IdentityServer clears its session cookie
5. IdentityServer notifies other client applications (via front-channel or back-channel logout)
6. IdentityServer redirects back to PostLogoutRedirectUri (if configured)
```

### Important Notes

- **You MUST call SignOutAsync for both schemes.** Calling only `SignOutAsync("Cookies")` clears the local session but leaves the IdentityServer session active. On the next challenge, the user would be silently re-authenticated without being asked to log in again.

- **SignOutAsync("oidc")** triggers the OIDC handler to redirect the browser to IdentityServer's end session endpoint. This is what ensures the user is also logged out of IdentityServer and any other applications sharing that session.

- The `PostLogoutRedirectUri` can be configured on the OIDC handler options to control where the user lands after sign-out from IdentityServer:

```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.SignedOutCallbackPath = "/signout-callback-oidc"; // default
    // After IdentityServer processes the logout, user is redirected here
});
```
