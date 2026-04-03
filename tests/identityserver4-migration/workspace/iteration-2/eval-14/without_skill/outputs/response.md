# Issuer URI Considerations When Changing Hosting

When migrating between hosting environments (IIS to Kestrel+nginx), you need to be careful about the issuer URI.

## Why It Matters

The issuer URI (the `iss` claim in tokens) is used by clients and APIs to validate tokens. If it changes, existing tokens won't be accepted.

## What to Do

Check your current `.well-known/openid-configuration` to see what issuer is currently being used.

If you're changing the hosting setup, you should explicitly set the issuer:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://your-identity-server.com";
});
```

Also make sure your nginx reverse proxy is configured to forward the correct headers so the server knows the external URL.
