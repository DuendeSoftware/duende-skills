Here's how to set up server-side sessions with back-channel logout and session cleanup:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Session cleanup every 5 minutes
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
    .AddServerSideSessions();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This enables server-side sessions with:
- **Expired session cleanup** every 5 minutes
- **Back-channel logout** notifications when sessions expire
- **Server-side session store** to track active sessions

The `AddServerSideSessions()` call on the builder enables the server-side session feature. Expired sessions are cleaned up periodically and trigger back-channel logout to notify clients.

For coordinating token lifetimes with user sessions, you can set the client's `CoordinateLifetimeWithUserSession` property to `true` on individual client configurations. This ensures that when a user's session ends, their refresh tokens are also invalidated.
