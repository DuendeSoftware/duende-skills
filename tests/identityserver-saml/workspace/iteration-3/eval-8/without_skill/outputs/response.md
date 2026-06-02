# SAML Service Provider Configuration Validation

When configuring a SAML service provider in Duende IdentityServer, there are several requirements to meet.

## Common Requirements

### Entity ID
Every service provider must have a unique Entity ID. This is typically a URI that identifies the SP:

```csharp
EntityId = "https://hr.example.com"
```

### Assertion Consumer Service (ACS) URL
You need at least one ACS endpoint where SAML responses will be sent:

```csharp
AssertionConsumerService = new Endpoint
{
    Location = "https://hr.example.com/sso",
    Binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
}
```

### Signing Certificate
The SP should provide a signing certificate for request validation.

### Metadata
Ensure your SP metadata is accessible and properly formatted. IdentityServer can often import SP configuration from metadata URLs.

## Troubleshooting

- Verify the Entity ID matches exactly between your SP configuration and the actual SP
- Check that the ACS URL is reachable from the IdP
- Ensure certificates are valid and not expired
- Check clock synchronization between IdP and SP
