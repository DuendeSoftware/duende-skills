# Server-Side Session Hardening

## Configuration

### IdentityServer Options

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Absolute cookie lifetime — no indefinite sessions
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);

    // No sliding expiration — prevents sessions from being extended indefinitely
    options.Authentication.CookieSlidingExpiration = false;

    // Tie client token lifetimes to user session — tokens are revoked when session ends
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Server-side session cleanup
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);

    // Trigger back-channel logout when server-side sessions expire
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
.AddInMemoryIdentityResources(/* ... */)
.AddInMemoryApiScopes(/* ... */)
.AddInMemoryClients(/* ... */);

// Enable server-side sessions
idsvrBuilder.AddServerSideSessions();
```

### Web.app Client — Back-Channel Logout

Configure the web.app client to receive back-channel logout notifications when the user's server-side session expires:

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // ... other settings ...

    // Back-channel logout: server-to-server session termination
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true,

    // Coordinate token lifetimes with user session
    CoordinateLifetimeWithUserSession = true
}
```

## How It Works

1. **Absolute cookie lifetime (8 hours)**: The authentication cookie expires after exactly 8 hours regardless of user activity. No sliding expiration means the session cannot be indefinitely extended.

2. **Expired session cleanup (every 10 minutes)**: A background process scans for expired server-side sessions every 10 minutes and removes them from the store.

3. **Back-channel logout on expiry**: When expired sessions are cleaned up and `ExpiredSessionsTriggerBackchannelLogout = true`, IdentityServer sends a back-channel logout request to each client's `BackChannelLogoutUri`. This is a server-to-server HTTP POST containing a logout token JWT.

4. **Coordinated client lifetimes**: `CoordinateClientLifetimesWithUserSession = true` ensures that refresh tokens and access tokens are revoked when the user's session ends, preventing orphaned tokens from persisting.

## Session Flow

```
User logs in → Server-side session created (8h absolute lifetime)
                ↓
After 8 hours → Session expires
                ↓
Cleanup job runs (every 10 min) → Finds expired session
                ↓
Back-channel logout sent → POST to https://app.example.com/bff/backchannel
                ↓
Client invalidates local session → User must re-authenticate
```
