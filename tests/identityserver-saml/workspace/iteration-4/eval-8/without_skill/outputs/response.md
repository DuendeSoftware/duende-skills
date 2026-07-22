# Common SAML SP Configuration Validation Requirements

When configuring a SAML Service Provider in IdentityServer, validation errors typically stem from a few well-known areas. Here's a rundown of the most common requirements and how to address them for your SP (`https://hr.example.com`).

## Reference Starting Point

Your current `Program.cs` has a standard Duende IdentityServer setup with OIDC clients only — no SAML is configured yet. To add the SP, you'll need to add the SAML plugin and define service provider registrations.

---

## Common Validation Requirements

### 1. Entity ID Must Match Exactly

The `EntityId` registered in IdentityServer must match **exactly** what the SP sends in its `AuthnRequest`. This is case-sensitive and whitespace-sensitive.

```csharp
new ServiceProvider
{
    EntityId = "https://hr.example.com",  // Must match SP's entityID exactly
    // ...
}
```

**Common mistake:** SP sends `https://hr.example.com/` (trailing slash) but IdP has `https://hr.example.com` (no trailing slash). These are treated as different entity IDs.

---

### 2. ACS URL Must Be Registered and Match

The Assertion Consumer Service (ACS) URL that the SP sends in requests (or that is in its metadata) must be registered in the IdP. For your SP:

```csharp
new ServiceProvider
{
    EntityId = "https://hr.example.com",
    AssertionConsumerServices =
    {
        new AssertionConsumerService
        {
            Binding = Saml2Constants.ProtocolBindings.HttpPost,  // or HttpRedirect
            Location = new Uri("https://hr.example.com/sso"),
            IsDefault = true,
            Index = 0
        }
    }
}
```

**Validation errors occur when:**
- The ACS URL in the `AuthnRequest` doesn't match any registered ACS URL
- The binding type doesn't match (SP requests HTTP-Redirect but only HTTP-POST is registered)
- The URL uses HTTP instead of HTTPS (many IdPs enforce HTTPS on ACS URLs)

---

### 3. HTTPS Is Required on ACS URLs (Recommended)

SAML assertions contain sensitive authentication data. Most IdP implementations will reject or warn about ACS URLs using plain HTTP. Your URL `https://hr.example.com/sso` already uses HTTPS — good.

---

### 4. Signing Certificate / Signature Validation

If the SP sends signed `AuthnRequest`s, the IdP needs the SP's public signing certificate to validate the signature. Conversely, the SP needs the IdP's signing certificate to validate assertion signatures.

```csharp
new ServiceProvider
{
    EntityId = "https://hr.example.com",
    // SP's certificate for signature validation (if SP signs AuthnRequests)
    SigningCertificates =
    {
        new X509Certificate2(Convert.FromBase64String("BASE64_CERT_DATA"))
    },
    // ...
}
```

**Validation errors occur when:**
- SP requires signed assertions but IdP signing isn't configured
- SP's certificate in IdP config is expired or incorrect
- Certificate thumbprint doesn't match

---

### 5. NameID Format Compatibility

If the SP specifies a `NameIDPolicy` format in its `AuthnRequest`, the IdP must support that format.

```csharp
new ServiceProvider
{
    EntityId = "https://hr.example.com",
    // ...
    // Restrict to formats the SP supports
    AllowedNameIdFormats =
    {
        "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified",
        "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
    }
}
```

---

### 6. Required Claims Must Be Mapped

If the SP expects specific SAML attributes (claims) in the assertion, they must be mapped and the user must have those claims. Missing required attributes can cause SP-side validation failures even after the IdP sends a valid assertion.

```csharp
new ServiceProvider
{
    EntityId = "https://hr.example.com",
    // ...
    ClaimsMapping = new Dictionary<string, string>
    {
        // Map SAML attribute name -> internal claim type
        { "urn:oid:1.3.6.1.4.1.5923.1.1.1.7", "role" },
        { "email", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" }
    }
}
```

---

### 7. Clock Skew / Time Validity

SAML assertions have `NotBefore` and `NotOnOrAfter` timestamps. If the clocks between IdP and SP are out of sync by more than a few minutes, validation will fail.

- Ensure both IdP and SP servers use NTP time synchronization
- Some SAML libraries allow configuring a clock skew tolerance (typically 2–5 minutes)

---

### 8. SP Metadata Import

Instead of manually entering all of the above, many SAML implementations allow importing SP metadata XML. If `https://hr.example.com` exposes a metadata endpoint (commonly at `/saml/metadata` or `/FederationMetadata/2007-06/FederationMetadata.xml`), you can import it:

```csharp
// Some SAML plugins support loading from metadata URL
var spMetadata = await SpMetadataLoader.LoadFromUrl("https://hr.example.com/saml/metadata");
```

This automatically populates EntityId, ACS URLs, certificates, and supported NameID formats.

---

## Minimal Valid SP Configuration Example

Putting it together for your SP:

```csharp
public static IEnumerable<ServiceProvider> ServiceProviders =>
[
    new ServiceProvider
    {
        EntityId = "https://hr.example.com",
        AssertionConsumerServices =
        {
            new AssertionConsumerService
            {
                Binding = Saml2Constants.ProtocolBindings.HttpPost,
                Location = new Uri("https://hr.example.com/sso"),
                IsDefault = true,
                Index = 0
            }
        },
        // Optional but recommended: require encrypted assertions
        EncryptionCertificates = { /* SP's encryption cert if using encrypted assertions */ },
        // SP signing cert if SP sends signed AuthnRequests
        SigningCertificates = { /* SP's signing cert */ }
    }
];
```

---

## Validation Error Diagnostic Steps

1. **Enable detailed SAML logging** — set log level to `Debug` for the SAML plugin namespace
2. **Check the SAML request/response** using browser dev tools (look for `SAMLRequest`/`SAMLResponse` POST parameters) and decode them with a tool like [samltool.com](https://www.samltool.com)
3. **Compare entity IDs** exactly — copy-paste from the decoded request to your config
4. **Verify ACS URL binding** — ensure the binding in config matches what the SP requests
5. **Check certificate validity** — ensure no certs have expired
