# Setting Up Signing Keys and Data Protection

## Replace Developer Signing Credential

The developer signing credential should not be used in production. Here's how to set up proper key management:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure Data Protection
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// IdentityServer configuration
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
});

// Add identity resources, scopes, clients...
idsvrBuilder.AddInMemoryIdentityResources(/* ... */);
idsvrBuilder.AddInMemoryApiScopes(/* ... */);
idsvrBuilder.AddInMemoryClients(/* ... */);
```

## Key Points

- Remove `AddDeveloperSigningCredential()` for production
- IdentityServer's automatic key management handles rotation
- Data Protection is configured with persistent file storage for load-balanced deployments
- Keys rotate every 90 days with 14-day propagation time

Note: You should also consider using RS256 or ES256 algorithms for signing. Configure the algorithms based on your client compatibility needs.
