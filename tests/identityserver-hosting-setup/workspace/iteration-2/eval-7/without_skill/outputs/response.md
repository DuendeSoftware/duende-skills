# IdentityServer Hosting Pattern

## Co-hosting vs Separate Host

Co-hosting IdentityServer with your API is possible and can work for simpler deployments. It reduces the number of services you need to deploy and manage.

However, for larger applications, having a separate identity server gives you better separation of concerns. It's really a trade-off between simplicity and security.

## IssuerUri

You should set the `IssuerUri` explicitly to ensure consistency:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
});
```

This ensures the issuer is always consistent regardless of which URL the server is accessed from. Without it, the issuer will change based on the request URL, which could cause token validation issues if your server is accessed through multiple URLs.
