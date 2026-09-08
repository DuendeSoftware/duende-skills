# Enabling Server-Side Sessions with Back-Channel Logout

Duende IdentityServer supports server-side sessions, which store the session server-side and enable back-channel logout when sessions expire. You enable it with `AddServerSideSessions()` and tune the behavior through `IdentityServerOptions.ServerSideSessions`.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Clean up expired sessions every 5 minutes
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // Trigger back-channel logout when sessions expire
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
    .AddServerSideSessions()
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

To make sure refresh tokens are revoked when the user's session ends, coordinate the client's token lifetime with the user session. This is a per-client setting:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    AllowOfflineAccess = true,

    // Revoke refresh tokens when the user session ends
    CoordinateLifetimeWithUserSession = true,

    // Needed so back-channel logout can reach this client
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",

    AllowedScopes = { "openid", "profile" }
}
```

## Notes

- `AddServerSideSessions()` turns on the server-side session store.
- `RemoveExpiredSessionsFrequency` sets the cleanup cadence (5 minutes here).
- `ExpiredSessionsTriggerBackchannelLogout = true` sends logout notifications to clients when their session is cleaned up.
- Setting `CoordinateLifetimeWithUserSession = true` on the client ties its refresh token lifetime to the session so tokens stop working after logout/expiry. Each client that should receive logout notifications needs a `BackChannelLogoutUri`.
