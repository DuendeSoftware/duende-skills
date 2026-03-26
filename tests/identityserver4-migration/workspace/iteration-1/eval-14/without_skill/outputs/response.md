# Issuer URI Concerns When Migrating IdentityServer

## The Risk

When you change hosting environments, the issuer URI could change. The issuer (`iss` claim) in tokens must remain the same, or clients and APIs won't be able to validate tokens.

## What to Do

### Check Current Issuer
Look at your current discovery document:
```
GET https://your-server/.well-known/openid-configuration
```
Note the `issuer` value.

### Set It Explicitly
Configure the issuer URI explicitly in Duende IdentityServer:
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.example.com";
});
```

### Configure Reverse Proxy
Make sure nginx forwards the correct headers so IdentityServer knows the public-facing URL:
```csharp
app.UseForwardedHeaders();
```
