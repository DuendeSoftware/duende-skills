Azure Key Vault keys marked non-exportable can't be loaded as `X509Certificate2` with a private key, so you implement signing through the Key Vault `CryptographyClient`.

```csharp
// dotnet add package Azure.Security.KeyVault.Keys Azure.Identity
var keyClient = new KeyClient(new Uri("https://myvault.vault.azure.net/"), new DefaultAzureCredential());
KeyVaultKey kvKey = keyClient.GetKey("signing-key");
var crypto = new CryptographyClient(kvKey.Id, new DefaultAzureCredential());

builder.Services.AddSingleton(crypto);
builder.Services.AddSingleton<ISigningCredentialStore, KeyVaultSigningCredentialStore>();
builder.Services.AddSingleton<IValidationKeysStore, KeyVaultValidationKeysStore>();
builder.Services.AddIdentityServer(o => o.KeyManagement.Enabled = false);
```

The credential store returns a `SigningCredentials` whose `SecurityKey` has a custom `CryptoProviderFactory` that delegates `SignData` to `CryptographyClient.SignData(RS256, bytes)`. The validation store returns the public key (`RsaSecurityKey` from `kvKey.Key`) with the `kid`.

**SAML:** SAML needs an X.509 certificate for signing and metadata. Use a Key Vault *certificate* (its key is non-exportable) and expose the public certificate in metadata, while signing delegates to Key Vault via `RSA` created by `RSAKeyVaultProvider` (`Azure.Security.KeyVault.Keys.Cryptography`/ `RSAKeyVaultProvider` `GetRSAPrivateKey`)... that returns an `X509Certificate2.CopyWithPrivateKey(rsa)`. I'm not certain how the SAML component consumes it, so confirm against the Duende SAML docs.
