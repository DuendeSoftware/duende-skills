# SAML Service Provider Validation Requirements

Duende IdentityServer automatically validates all SAML service provider configurations through a `ValidatingSamlServiceProviderStore<T>` wrapper. When validation fails, the SP is **treated as non-existent** (the store returns null), which means AuthnRequests from that SP will fail with an "unknown service provider" error.

## Validation Requirements

Here's what the validator checks:

### 1. EntityId is Required
The `EntityId` property must be set and non-empty.

### 2. At Least One ACS URL with HTTP-POST Binding
`AssertionConsumerServiceUrls` must contain at least one entry, and it **must use HTTP-POST binding**. HTTP-Redirect is not supported for ACS endpoints:

```csharp
// CORRECT
AssertionConsumerServiceUrls =
[
    new IndexedEndpoint
    {
        Location = "https://hr.example.com/sso",
        Binding = SamlBinding.HttpPost,  // Must be HttpPost
        Index = 0,
        IsDefault = true
    }
]

// WRONG — will fail validation
AssertionConsumerServiceUrls =
[
    new IndexedEndpoint
    {
        Location = "https://hr.example.com/sso",
        Binding = SamlBinding.HttpRedirect,  // Not supported for ACS!
        Index = 0,
        IsDefault = true
    }
]
```

### 3. At Least One AllowedScopes Entry
`AllowedScopes` must contain at least one scope. Without it, the SP gets no claims in the assertion (and fails validation):

```csharp
AllowedScopes = ["openid", "profile", "email"]
```

### 4. Positive Lifetime Values
Any configured lifetime (assertion lifetime, etc.) must be positive.

## Working Example

```csharp
new SamlServiceProvider
{
    EntityId = "https://hr.example.com",
    DisplayName = "HR Application",
    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://hr.example.com/sso",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],
    AllowedScopes = ["openid", "profile", "email"],
    SigningBehavior = SamlSigningBehavior.SignAssertion
}
```

## Key Takeaway

If you're getting validation errors and the SP seems to "not exist," check these four things: EntityId set, ACS with HTTP-POST, AllowedScopes non-empty, and positive lifetimes. Invalid SPs are silently treated as non-existent — there's no explicit error response to the SP, just a lookup failure.
