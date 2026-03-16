# Fixing IDX20803 Configuration Error in Aspire

## The Problem

This error occurs because your API is trying to reach IdentityServer's discovery endpoint before IdentityServer is ready to serve requests.

## Solution

Make sure your API depends on IdentityServer in the AppHost:

```csharp
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);
```

`WaitFor` ensures the API doesn't start until IdentityServer is healthy, and `WithReference` makes the endpoint URL available.

## Additional Tips

- Make sure IdentityServer's URL is correctly configured in the API
- Check that IdentityServer can serve the discovery document at `/.well-known/openid-configuration`
- Consider adding retry logic in the API for resilience
