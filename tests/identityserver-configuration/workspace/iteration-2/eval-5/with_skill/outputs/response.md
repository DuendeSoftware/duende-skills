Here's the `Program.cs` configured with server-side sessions, back-channel logout for expired sessions, and coordinated client lifetimes:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Configure session cleanup to run every 5 minutes
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // Trigger back-channel logout when expired sessions are cleaned up
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;

    // Coordinate client token lifetimes with the user session
    // This ensures refresh tokens are revoked when a user's session ends
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
})
    // Enable server-side sessions — this is a builder method, not an option property
    .AddServerSideSessions();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key configuration details:**

1. **`.AddServerSideSessions()`** is called on the IdentityServer builder chain (not as an options property). This enables server-side session storage, moving authentication state from the cookie to a server-side store.

2. **`options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5)`** sets the cleanup interval to 5 minutes (default is 10 minutes).

3. **`options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true`** ensures that when the cleanup job finds expired sessions, it sends back-channel logout notifications to all clients that have a `BackChannelLogoutUri` configured.

4. **`options.Authentication.CoordinateClientLifetimesWithUserSession = true`** coordinates refresh token lifetimes with the user session. When a user's session ends (expires or is revoked), their refresh tokens are also revoked.

> **Note:** By default, server-side sessions use an in-memory store. For production, configure a durable store using `AddOperationalStore()` with EF Core or implement a custom `IServerSideSessionStore`.
