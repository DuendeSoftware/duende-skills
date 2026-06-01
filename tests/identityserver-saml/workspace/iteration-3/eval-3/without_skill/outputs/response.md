# Mapping Claims to SAML Attributes

When configuring a SAML service provider in Duende IdentityServer, you can map claims to specific SAML attribute URIs using claim mapping configuration.

## Configure Claim Mappings

In your service provider configuration, you can define claim-to-attribute mappings:

```csharp
new ServiceProvider
{
    EntityId = "https://sp.example.com",
    ClaimMapping = new Dictionary<string, string>
    {
        { "email", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" },
        { "department", "urn:custom:department" }
    }
}
```

## How It Works

The claim mapping translates the internal claim names used by IdentityServer into the SAML attribute names expected by the service provider. The key is the internal claim name and the value is the SAML attribute URI.

## Global Defaults

You can also configure default mappings that apply to all service providers:

```csharp
services.AddIdentityServer(options =>
{
    options.Saml.DefaultAttributeMapping = new Dictionary<string, string>
    {
        { "email", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" },
        { "name", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name" }
    };
});
```

Individual SP mappings will override the global defaults for specific claims.
