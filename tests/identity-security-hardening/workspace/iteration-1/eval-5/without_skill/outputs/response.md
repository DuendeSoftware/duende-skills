# Replacing Developer Signing Credential

## Remove AddDeveloperSigningCredential

The developer signing credential is for development only. For production, use proper key management.

## Configure Key Management

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
});
```

For ES256 as primary with RS256 fallback, you would need to configure the signing algorithms. However, the exact API for this depends on the version of IdentityServer you're using.

## Data Protection

For load-balanced deployment, configure shared Data Protection:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");
```

Make sure the `/var/identity/dp-keys` directory is accessible by all instances and has appropriate permissions.
