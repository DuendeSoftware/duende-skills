```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
.AddCookie("Cookies")
.AddOpenIdConnect("oidc", options =>
{
    options.Authority = "https://identity.example.com";
    options.ClientId = "web.app";
    options.ClientSecret = "secret";
    options.ResponseType = "code";
    options.MapInboundClaims = false;
    options.SaveTokens = true;   // id_token is kept for id_token_hint
});

builder.Services.AddAuthorization();
var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/logout", async (HttpContext ctx) =>
{
    // clears the local cookie
    await ctx.SignOutAsync("Cookies");
    // redirects to IdentityServer /connect/endsession
    await ctx.SignOutAsync("oidc", new AuthenticationProperties { RedirectUri = "/" });
});

app.MapGet("/", () => "Hello World!");
app.Run();
```

## Sign-out flow

1. `SignOutAsync("Cookies")` clears the local cookie.
2. `SignOutAsync("oidc")` redirects the browser to IdentityServer's `/connect/endsession`.
3. IdentityServer clears its own session.
4. IdentityServer notifies other clients via front-channel or back-channel logout.
5. IdentityServer redirects to the post-logout redirect URI (registered on the client), where the `RedirectUri` takes the user back.

Signing out of only `"Cookies"` leaves the IdentityServer session alive, so the next challenge silently re-authenticates the user. Always sign out of both schemes.
