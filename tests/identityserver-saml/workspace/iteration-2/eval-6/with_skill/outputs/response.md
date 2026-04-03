# SAML Signing Behaviors in Duende IdentityServer

Duende IdentityServer supports four signing behaviors for SAML responses:

## All Four Signing Behaviors

| Behavior | Signs | Notes |
|---|---|---|
| **`SignAssertion`** | Assertion only | **Default** and most interoperable option |
| **`SignResponse`** | Entire SAML response | Some SPs require this |
| **`SignBoth`** | Both assertion and response | Maximum security, less common |
| **`DoNotSign`** | Nothing | **Testing only** — never use in production |

## Recommendation for Your Case

Since your SP requires both the assertion and the full response to be signed, use **`SignBoth`**:

```csharp
// Per-SP configuration
var sp = new SamlServiceProvider
{
    EntityId = "https://sp.example.com",
    DisplayName = "SP Requiring Both Signatures",
    AssertionConsumerServiceUrls =
    [
        new Uri("https://sp.example.com/saml/acs")
    ],
    SigningBehavior = SamlSigningBehavior.SignBoth
};
```

## Setting as Default

You can also set the default signing behavior for all SPs via `IdentityServerOptions`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Saml.DefaultSigningBehavior = SamlSigningBehavior.SignBoth;
});
```

## Key Points

- **`SignAssertion`** is the default and most interoperable — use it unless an SP specifically requires something else
- **`SignBoth`** provides maximum security by signing both the assertion and the response envelope
- **`DoNotSign`** should **never** be used in production — it removes all integrity protection from the SAML response
- The per-SP `SigningBehavior` overrides the global default set in `options.Saml.DefaultSigningBehavior`
