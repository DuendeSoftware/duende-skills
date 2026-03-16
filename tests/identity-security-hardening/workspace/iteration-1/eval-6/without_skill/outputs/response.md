# Configuring Server-Side Sessions

Here's how to configure sessions with specific lifetimes:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
})
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
        BackChannelLogoutSessionRequired = true,
        // other settings...
    }
});
```

For server-side sessions, you'd need to configure session storage. Duende IdentityServer supports server-side sessions that can track and manage active sessions.

You should also configure the cleanup of expired sessions and consider back-channel logout for when sessions expire on the server side.
