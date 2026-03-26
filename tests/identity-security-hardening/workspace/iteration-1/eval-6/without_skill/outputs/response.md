# Configuring Server-Side Sessions

## Session Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
});
```

## Enable Server-Side Sessions

You'll need to call a method to enable server-side sessions. In Duende IdentityServer, this is typically done on the builder:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
});

idsvrBuilder.AddServerSideSessions();
```

## Back-Channel Logout

For the web.app client, add back-channel logout support:

```csharp
new Client
{
    ClientId = "web.app",
    // ... other settings ...
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true
}
```

## Expired Session Cleanup

You should configure cleanup of expired sessions. I believe there are server-side session options for this in IdentityServer, but the exact property names may vary by version.
