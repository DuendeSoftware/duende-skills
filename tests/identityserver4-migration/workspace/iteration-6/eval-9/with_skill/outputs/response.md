## License key

Configure it in `AddIdentityServer`:
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

**Where to store it**: a secret manager (user-secrets in development), an environment variable (`IdentityServer__LicenseKey`), or a key vault. **Never** in source-controlled `appsettings.json`.

**Without a key**: IdentityServer runs in community/trial mode and logs a warning on startup. This is acceptable for local development, but a license is required for production use.

**Choosing the edition**: it depends on your client inventory — count interactive clients (authorization code: web apps, SPAs, native) versus non-interactive (client credentials: M2M). For your sample that's one of each (`interactive.client`, `m2m.client`). Duende's Migration Analysis Tool, run against the old IS4 instance, reports those counts. Note that automatic key management is a Business/Enterprise feature; on Community edition use a static signing credential (`AddSigningCredential`) instead of the removed `AddDeveloperSigningCredential()`.

See Duende IdentityServer pricing for edition thresholds.
