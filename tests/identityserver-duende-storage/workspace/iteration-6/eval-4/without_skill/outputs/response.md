Yes, there are some concerns. I don't know the exact `IIdentityProviderAdmin` API, so this is general guidance.

1. **Plaintext at rest**: if the `ClientSecret` is stored as a plain string in the identity provider's properties, anyone with DB read access, backups or logs can read it. Unlike client secrets for your own clients, it can't be hashed because IdentityServer has to send it to the upstream IdP.
2. **Encrypt it**: use ASP.NET Core Data Protection (persisted and protected keys) or a KMS/Key Vault envelope to encrypt it before storing. Decrypt only when building the handler options.
3. **Never return it from the admin API**: write-only. Redact it in responses, logs and audit trails.
4. **Least privilege**: restrict who can call the admin API (HTTPS only, authorization policy) and who can read the table.
5. **Rotation**: support secret rotation and don't cache it longer than necessary.
6. **Prefer alternatives**: for upstream IdPs that support it, use `private_key_jwt` or certificates instead of shared secrets, or store a reference to a secret in a vault rather than the value.
