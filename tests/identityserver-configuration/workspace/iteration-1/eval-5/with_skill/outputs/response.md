Here's how to enable server-side sessions with the settings you need:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;

    // Server-side session cleanup and back-channel logout
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;

    // Coordinate client token lifetimes with the user session
    // When a user's session ends, refresh tokens issued during that session are revoked
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
})
    // Enable server-side sessions — this is called on the builder, not as an option
    .AddServerSideSessions();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### How It Works

1. **`.AddServerSideSessions()`** — Called on the IdentityServer builder (not as an option property). This replaces the default cookie-only session behavior with a server-side store. There is no `options.ServerSideSessions.Enabled` property — the feature is activated by this builder method call.

2. **`RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5)`** — A background task runs every 5 minutes to clean up expired sessions from the server-side store.

3. **`ExpiredSessionsTriggerBackchannelLogout = true`** — When the cleanup task finds an expired session, it sends back-channel logout notifications to all clients that had tokens issued during that session. This ensures clients are informed when a user's session ends, even if the user didn't explicitly log out.

4. **`CoordinateClientLifetimesWithUserSession = true`** — This ties client token lifetimes (including refresh tokens) to the user's server-side session. When a session is revoked or expires, the refresh tokens associated with that session are also revoked. This prevents long-lived refresh tokens from outliving the user's authentication session.

### Important Notes

- Server-side sessions require a session store. The default is an in-memory store (suitable for development). For production, use the EF Core operational store (see `identityserver-stores` skill) or implement `IServerSideSessionStore`.
- Back-channel logout requires clients to have a `BackChannelLogoutUri` configured.
- The `CoordinateClientLifetimesWithUserSession` setting is on `options.Authentication`, not on `options.ServerSideSessions`.
