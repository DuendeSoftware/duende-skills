## License key

Set it in `AddIdentityServer` options:
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```
Alternatively place a file named `Duende_License.key` in the app's content root; Duende reads it automatically.

**Where to store**: not in source control. Use environment variables (`IdentityServer__LicenseKey`), user-secrets for development, and Azure Key Vault / AWS Secrets Manager / Kubernetes secrets for production, loaded through configuration.

**Without a key**: IdentityServer runs in trial/community mode. It logs warnings/errors at startup and at runtime, but continues to function; there's no hard feature lockout in development/testing. Production use without a license violates the license terms, and if you exceed edition limits (clients, issuers) or use features not in your edition you get logged warnings. A Community Edition license is available for small organizations/non-profits.
