# Server-Side Sessions with Back-Channel Logout

Here's the configuration that enables server-side sessions, back-channel logout on expiry, and coordinates token lifetimes with user sessions:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Session cleanup and back-channel logout
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;

    // Coordinate client token lifetimes with user session
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
})
    // Enable server-side sessions - this is a builder call, not an option
    .AddServerSideSessions();

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## How It Works

### Server-Side Sessions

Calling `.AddServerSideSessions()` on the IdentityServer builder (not as an option property) enables server-side session storage. Instead of storing the full authentication session in the cookie, only a session ID is stored. The full session data lives server-side.

### Session Expiry Cleanup

`RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5)` runs a background task every 5 minutes to clean up expired sessions.

### Back-Channel Logout on Expiry

When `ExpiredSessionsTriggerBackchannelLogout = true`, the cleanup task sends back-channel logout notifications to all clients that were part of the expired session. This ensures clients invalidate their local sessions when the IdentityServer session expires.

### Coordinated Token Lifetimes

`CoordinateClientLifetimesWithUserSession = true` ties refresh token and access token lifetimes to the user's session. When a user's session ends (via logout or expiry), their refresh tokens are effectively revoked — the next refresh attempt will fail because the session no longer exists.

This prevents the scenario where a user logs out but a previously issued refresh token continues to work for hours or days.
