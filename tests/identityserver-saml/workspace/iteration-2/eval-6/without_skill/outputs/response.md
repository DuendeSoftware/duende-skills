# SAML Signing Options

SAML supports signing the assertion, the response, or both. Here are the typical options:

1. **Sign Assertion** — Signs just the SAML assertion within the response
2. **Sign Response** — Signs the entire SAML response envelope
3. **Sign Both** — Signs both the assertion and the response

For your case where the SP requires both to be signed, you'd want to configure signing for both the assertion and the response. The configuration depends on your SAML library:

```csharp
// Example configuration (syntax varies by library)
var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    // SigningBehavior = SignBoth or equivalent
};
```

Signing the assertion is the most common approach and provides the best interoperability. Signing both is more secure but less commonly required.
