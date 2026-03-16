# Migrating IdentityServer4 with Issuer URI Considerations

When migrating from IdentityServer4 to Duende IdentityServer and changing your hosting infrastructure, the issuer URI is an important consideration.

## What is the Issuer URI?

The issuer URI is the identifier for your identity provider. It appears as the `iss` claim in tokens and in the discovery document at `/.well-known/openid-configuration`. In IdentityServer4, if you didn't set an explicit `IssuerUri`, it was derived from the incoming request URL.

## Key Concern: Issuer Must Stay the Same

When changing from IIS on Windows to Kestrel behind nginx on Linux, the issuer URI must remain the same. If it changes:

- Existing tokens will fail validation because the `iss` claim won't match what APIs expect
- Client applications that have your authority URL configured may reject responses
- Refresh tokens may become invalid

## Recommended Steps

### Set an explicit issuer URI

In your Duende IdentityServer configuration, explicitly set the issuer:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://your-identity-server.example.com";
});
```

### Configure forwarded headers

Since you're behind nginx, configure forwarded headers so the application sees the correct scheme and host:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
});

app.UseForwardedHeaders();
```

### Verify the discovery document

After migration, check `/.well-known/openid-configuration` to confirm the issuer value matches the original.

## Additional Hosting Considerations

- Ensure nginx is configured to pass `X-Forwarded-For` and `X-Forwarded-Proto` headers
- Test that HTTPS termination at nginx is handled correctly
- Verify that all redirect URIs still work with the new hosting setup
