# Adding SAML 2.0 IdP support (best-effort; API names from memory, verify against your version)

Duende IdentityServer 8 can act as a SAML 2.0 IdP (Enterprise-level feature). Steps:

1. Enable it on the builder and register the SP.
2. Make sure a signing credential is configured (SAML assertions are signed).
3. Map the SAML endpoints (metadata, SSO) — normally done by `UseIdentityServer()`.

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml()
    .AddInMemorySamlServiceProviders(new[]
    {
        new SamlServiceProvider
        {
            EntityId = "https://crm.contoso.com",
            DisplayName = "Contoso CRM",
            AssertionConsumerServiceUrls = { new Uri("https://crm.contoso.com/saml/acs") },
            AssertionConsumerServiceBinding = SamlBinding.HttpPost,
            RequireSignedAuthnRequests = false
        }
    });
```

Notes:
- Give the SP your IdP metadata URL (typically `/saml/metadata`).
- The SP's ACS URL must be registered exactly; IdentityServer rejects mismatching ACS URLs.
- Configure a real signing key/certificate for production; the SAML signature uses the same key store as token signing.
- Use `AllowedClaims`/claim mappings to decide which attributes appear in the assertion.
