# Fixing IDX20803: Unable to Obtain Configuration

The error `IDX20803: Unable to obtain configuration from '.well-known/openid-configuration'` typically means your API can't reach the IdentityServer's discovery endpoint.

## Common Causes and Fixes

### 1. Incorrect Authority URL

Make sure your API's JWT Bearer configuration points to the correct IdentityServer URL:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://localhost:5001"; // Make sure this matches your IdentityServer URL
    });
```

### 2. IdentityServer Not Running

Ensure IdentityServer is actually running and accessible. Try navigating to `https://localhost:5001/.well-known/openid-configuration` in your browser.

### 3. SSL Certificate Issues

If you're running in development, you might need to trust the dev certificate:

```bash
dotnet dev-certs https --trust
```

### 4. Startup Order in Aspire

In Aspire, services start in parallel. You can add a reference to ensure your API knows about IdentityServer:

```csharp
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer);
```

### 5. Retry Policy

You can also add a retry policy to your authentication handler so it retries fetching the configuration:

```csharp
options.BackchannelHttpHandler = new HttpClientHandler();
options.RefreshInterval = TimeSpan.FromMinutes(5);
```

Check the IdentityServer logs to see if it's encountering any errors during startup that might prevent it from serving the discovery document.
