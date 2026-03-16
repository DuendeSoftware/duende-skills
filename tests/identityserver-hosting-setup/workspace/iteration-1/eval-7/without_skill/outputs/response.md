# IdentityServer Hosting Pattern

## Hosting Recommendation

While co-hosting IdentityServer with your API would reduce deployment complexity, it's generally better to keep them separate. Here's why:

- **Security isolation**: IdentityServer handles sensitive operations like authentication and token issuance. Keeping it separate reduces the risk that a vulnerability in your API could compromise your identity provider.
- **Independent scaling**: You can scale your API and identity server independently based on their different load patterns.
- **Simpler middleware**: Each application has its own middleware pipeline without conflicts.

That said, for small teams and simple applications, co-hosting can work if you're careful about middleware configuration.

## IssuerUri Configuration

For the IssuerUri, you have two options:

1. **Set it explicitly**: Use `options.IssuerUri = "https://identity.mycompany.com"` to ensure consistent token issuance regardless of how the server is accessed.

2. **Let it be inferred**: Don't set it, and IdentityServer will use the request URL automatically.

For most deployments, setting it explicitly is recommended to ensure consistency, especially if you might access the server via different URLs (e.g., internal vs external).

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
});
```
