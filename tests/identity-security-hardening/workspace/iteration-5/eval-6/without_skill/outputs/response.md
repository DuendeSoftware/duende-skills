# Server-Side Sessions and Back-Channel Logout

Here's how I'd approach hardening the sessions. Duende IdentityServer supports server-side sessions, which store the session state on the server so you can expire them centrally and drive back-channel logout.

## Enable server-side sessions

Register the server-side session store on the IdentityServer builder:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */);

idsvrBuilder.AddServerSideSessions();
```

## Configure cookie lifetime and cleanup

To get an absolute 8-hour session with no sliding expiration, configure the application cookie used for the login session:

```csharp
builder.Services.ConfigureApplicationCookie(options =>
{
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = false;
});
```

For cleaning up expired sessions periodically, you can enable the session cleanup so stale sessions are removed on a schedule (roughly every 10 minutes). Check the `ServerSideSessions` options exposed by IdentityServer for the exact cleanup interval property in your version.

## Configure the client for back-channel logout

Set a back-channel logout URI on the `web.app` client so IdentityServer can notify it (server-to-server) when the session ends:

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true,

    // ... redirect URIs, scopes ...
}
```

## Summary

- Server-side sessions are enabled with `AddServerSideSessions()`.
- The login cookie is given an 8-hour absolute lifetime with sliding expiration turned off.
- Expired sessions should be cleaned up periodically; enable that in the server-side session options.
- The `web.app` client gets a `BackChannelLogoutUri` (HTTPS) so it can be signed out server-to-server when the session terminates.

One thing to verify against your IdentityServer version: the exact option names for triggering back-channel logout on session expiration and for coordinating client token lifetimes with the user session — those live under the IdentityServer options and I'd confirm them in the docs before relying on them.
