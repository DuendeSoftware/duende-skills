Yes. **Dynamic identity provider properties such as `ClientSecret` are stored recoverably in Duende Storage (preview). They are not hashed and not field-encrypted.** That differs from client secrets and API secrets, which are hashed on write. IdentityServer needs the actual value to call the upstream IdP, so it can't be one-way.

**Mitigations:**
- **Encrypted connections** (TLS) to the database.
- **Encryption at rest** for the database and its storage.
- **Restricted DB access**: only the IdentityServer runtime identity (and DBAs on a need-to-know basis) should read the configuration store. Don't hand out direct read access as a stand-in for an admin workflow.
- **Protected backups**: they contain the secrets in recoverable form, so encrypt them and control access.
- **Go through the admin API**, `IIdentityProviderAdmin`, behind proper authentication, authorization and auditing. It's a .NET service, not an HTTP endpoint, so you build and secure the host (add anti-forgery if it's browser-based).
- **Take the secret from a vault** at provisioning time and keep it out of source control and logs.
- If you migrate from EF Core, move these values only through a protected process.
- Remember to register `AddOidcDynamicProvider()` for the IdPs you create.

```csharp
await idpAdmin.CreateAsync(new IdentityProviderConfiguration
{
    Scheme = "partner-oidc",
    Type = "oidc",
    Properties = { ["Authority"] = "https://partner.example", ["ClientId"] = "ids", ["ClientSecret"] = secretFromVault }
}, ct);
```
(Property names illustrative; check the model. Treat the DB as secret-bearing.)
