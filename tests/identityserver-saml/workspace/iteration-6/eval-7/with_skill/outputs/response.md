# Requirements for SAML IdP support

- **NuGet package**: none extra. SAML 2.0 IdP support is built into `Duende.IdentityServer` **v8.0+**. Enable with `.AddSaml()`.
- **License**: **Standard (add-on), Advanced, or Custom Edition**. (Not available in the base Starter/Business tiers without the add-on.)
- **.NET**: IdentityServer v8 targets **.NET 10** (`net10.0`).

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

Also: use X.509-capable signing keys, and plan EF Core migrations (`Update_DuendeIdentityServer_v8_0`) if you use the EF stores.
