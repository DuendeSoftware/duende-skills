# SAML Signing Behaviors in Duende IdentityServer

Duende IdentityServer supports four signing behaviors for SAML responses, controlled via `SamlSigningBehavior`:

## The Four Signing Behaviors

| Behavior | What Gets Signed | Use Case |
|---|---|---|
| **`SignAssertion`** | Assertion only | **Default and most interoperable.** Works with the widest range of SPs. |
| **`SignResponse`** | Entire SAML response | Some SPs require the full response to be signed rather than just the assertion. |
| **`SignBoth`** | Both assertion and response | Maximum security. Signs both the inner assertion and the outer response envelope. |
| **`DoNotSign`** | Nothing | **Testing only — never use in production.** Useful for debugging assertion content without signature validation issues. |

## Recommendation for Your Case

Since your SP requires both the assertion and the full response to be signed, use **`SignBoth`**:

```csharp
var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "SP Requiring Dual Signing",
    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],
    SigningBehavior = SamlSigningBehavior.SignBoth
};
```

## Setting a Default for All SPs

You can set the default signing behavior for all service providers via `IdentityServerOptions.Saml.DefaultSigningBehavior`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Saml.DefaultSigningBehavior = SamlSigningBehavior.SignBoth;
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

Per-SP `SigningBehavior` overrides the default.

## Key Considerations

- **`SignAssertion`** (default) is recommended as the baseline — it's the most interoperable option and sufficient for most SPs
- **`SignBoth`** provides maximum security but generates larger responses and uses more CPU for signature computation
- **`DoNotSign`** should **never** be used in production — it removes all cryptographic proof of assertion authenticity
- **`SignResponse`** is for SPs that validate the response signature but not the assertion signature (less common)
- The signing key used is IdentityServer's configured signing credential (same key used for JWT signing)