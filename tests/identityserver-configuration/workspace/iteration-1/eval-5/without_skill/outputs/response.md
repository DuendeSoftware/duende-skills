# Server-Side Sessions Configuration

To enable server-side sessions with back-channel logout:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
});
```

This configures IdentityServer to:
- Clean up expired sessions every 5 minutes
- Send back-channel logout notifications when sessions expire
- Coordinate refresh token lifetimes with user sessions

You'll also want to set up a session store (like Entity Framework) so session data persists across application restarts.
