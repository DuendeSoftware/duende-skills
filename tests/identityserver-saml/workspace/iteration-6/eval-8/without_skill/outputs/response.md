# Common SAML SP validation requirements

For `https://hr.example.com` with ACS `https://hr.example.com/sso`:

- **EntityId** required, unique, absolute URI (an exact string match is used for lookup, so `https://hr.example.com` vs trailing-slash matters).
- **At least one ACS URL**, absolute, and generally HTTPS (HTTP only for dev). The ACS in the AuthnRequest must exactly match a registered one.
- **ACS binding**: HTTP-POST (default) or Artifact; must be supported.
- **Signing certificates** are required if you require signed AuthnRequests.
- **SLO URL** valid if logout is enabled.
- **Claim mappings / NameID format** must be valid URIs.
- The URL is `/sso`, which is fine, but check for ports/paths mismatches.

```csharp
new SamlServiceProvider
{
    EntityId = "https://hr.example.com",
    DisplayName = "HR",
    AssertionConsumerServiceUrls = { new Uri("https://hr.example.com/sso") }
}
```

Check logs for the exact message; it normally says which rule failed.
