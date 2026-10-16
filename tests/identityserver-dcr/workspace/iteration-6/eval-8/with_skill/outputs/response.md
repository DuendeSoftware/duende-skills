# Common DCR security mistakes and hardening

**1. Exposing `/connect/dcr` without authentication.** The most serious error: anyone can create clients. Always apply an authorization policy:
```csharp
app.MapDynamicClientRegistration().RequireAuthorization("dcr");
```
with JWT bearer (`ValidTypes = ["at+jwt"]`, correct audience) and `RequireClaim("scope", "IdentityServer.Configuration")`. Hand that scope only to trusted callers.

**2. Allowing any grant type.** Registrants shouldn't get `client_credentials`, password or implicit by default. Restrict in a `DynamicClientRegistrationValidator`:
```csharp
protected override Task ValidateGrantTypesAsync(DynamicClientRegistrationContext ctx)
{
    if (ctx.Request.GrantTypes.Any(g => g != "authorization_code"))
    { ctx.SetError("Grant type not allowed"); return Task.CompletedTask; }
    return base.ValidateGrantTypesAsync(ctx);
}
```

**3. Not enforcing PKCE / weak defaults.** Set `RequirePkce = true`, `AllowOfflineAccess = false`, short `AccessTokenLifetime` in `SetClientDefaultsAsync`.

**4. Weak redirect URI validation.** Require HTTPS (no http, wildcards or loose schemes) in `ValidateRedirectUrisAsync`.

**5. Unrestricted scopes.** Don't let registrants ask for any scope (admin, `IdentityServer.Configuration`, `api2`); allow-list.

**6. Trusting software statements incorrectly.** Validate signature, issuer and lifetime against a *trusted signing key*; reject missing statements if you require them; never accept unknown issuers.

**7. In-memory stores in production.** Registered clients disappear and nodes diverge; use the EF `IClientConfigurationStore` (`AddClientConfigurationStore()`).

**8. Plaintext client secrets.** Generated secrets must be stored hashed in your `IClientConfigurationStore`.

**9. Separate DCR host not sharing the data store.** If hosted separately, it must write to the database IdentityServer reads, with secured connectivity.

**10. Missing licensing/ops basics.** DCR needs Business Edition+. Add rate limiting, logging/auditing of registrations, HTTPS everywhere (see `identity-security-hardening`), and a cleanup/review process for stale dynamic clients.

**Checklist:** auth policy + scope ✔, `at+jwt`/audience ✔, grant types allow-list ✔, PKCE ✔, HTTPS redirects ✔, scope allow-list ✔, software statement trust ✔, EF store ✔, hashed secrets ✔, rate limiting and audit logs ✔.
