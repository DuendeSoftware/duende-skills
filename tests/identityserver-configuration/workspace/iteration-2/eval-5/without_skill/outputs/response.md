To enable server-side sessions with back-channel logout and coordinated lifetimes, you can configure IdentityServer like this:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

This configures the session cleanup to run every 5 minutes and triggers back-channel logout when expired sessions are cleaned up. The `CoordinateClientLifetimesWithUserSession` setting ensures refresh tokens are revoked when the user session ends.

You may also need to enable server-side sessions in the server options or through some additional configuration method.
