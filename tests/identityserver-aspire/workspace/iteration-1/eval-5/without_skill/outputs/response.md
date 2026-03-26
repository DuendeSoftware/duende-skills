# Fixing IDX20803 Discovery Configuration Error

The error `IDX20803: Unable to obtain configuration from .well-known/openid-configuration` means your API can't reach the IdentityServer discovery endpoint.

## Common Causes and Fixes

1. **IdentityServer isn't running**: Make sure IdentityServer is started before the API tries to connect.

2. **Wrong authority URL**: Check that the authority URL in your API configuration matches the actual IdentityServer URL:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://localhost:5001"; // Make sure this is correct
    });
```

3. **Network/certificate issues**: If using HTTPS, ensure the dev certificate is trusted.

4. **In Aspire**, make sure the projects are connected:

```csharp
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer);
```

5. **Retry policy**: Consider adding a retry policy for the backchannel HTTP handler:

```csharp
options.BackchannelHttpHandler = new HttpClientHandler();
```

The most common fix is ensuring the authority URL is correct and IdentityServer is accessible from the API.
