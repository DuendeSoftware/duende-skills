# SAML Signing Behaviors in Duende IdentityServer

Duende IdentityServer supports four SAML signing behaviors via the `SamlSigningBehavior` enum:

## All Four Signing Behaviors

| Behavior | What Gets Signed | Notes |
|----------|-----------------|-------|
| **`SignAssertion`** | Assertion only | **Default** and most interoperable. Recommended for most SPs. |
| **`SignResponse`** | Entire SAML response envelope | Some SPs require this instead of assertion signing. |
| **`SignBoth`** | Both the assertion AND the response | Maximum security. Use when the SP requires both to be signed. |
| **`DoNotSign`** | Nothing | **Testing only** — never use in production. Responses without signatures can be tampered with. |

## Your Requirement: Sign Both Assertion and Response

Since your SP requires both the assertion and the full response to be signed, use **`SignBoth`**:

### Per-Service Provider Configuration

```csharp
var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "SP Requiring Both Signatures",
    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],
    // Sign both the assertion and the response
    SigningBehavior = SamlSigningBehavior.SignBoth
};
```

### Global Default Configuration

You can also set the default signing behavior for all service providers via `IdentityServerOptions.Saml.DefaultSigningBehavior`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Set default signing behavior for all SPs
    options.Saml.DefaultSigningBehavior = SamlSigningBehavior.SignBoth;
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

Per-SP `SigningBehavior` overrides the global default.

## Recommendations

- **`SignAssertion`** (default) is the most interoperable and recommended for most scenarios
- **`SignBoth`** provides maximum security when the SP supports it — use it for your specific case
- **`SignResponse`** is needed by some SPs that validate response-level signatures only
- **`DoNotSign`** should **only be used for testing** — never in production. Unsigned responses provide no integrity guarantees and are vulnerable to tampering.
