# Hosting Pattern

## Co-Hosting Considerations

While it might seem simpler to put everything in one project, I'd recommend keeping IdentityServer separate from your API. The main reasons are:

1. **Security** — IdentityServer handles sensitive authentication data and should have a minimal attack surface
2. **Independent scaling** — You can scale each service independently
3. **Separation of concerns** — Different update cycles and configurations

## IssuerUri

For the IssuerUri, you can configure it like this:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
});
```

Setting it explicitly ensures consistency across environments. If you don't set it, IdentityServer will use the request URL, which can vary.
