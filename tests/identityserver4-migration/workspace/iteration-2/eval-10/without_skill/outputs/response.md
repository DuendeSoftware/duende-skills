# Migration Checklist: IdentityServer4 to Duende IdentityServer

1. **Update target framework** — Move from .NET Core 3.1 to .NET 8 or later
2. **Replace NuGet packages** — Swap IdentityServer4 packages for Duende.IdentityServer equivalents
3. **Update namespaces** — Change `IdentityServer4.*` to `Duende.IdentityServer.*`
4. **Update database** — Create EF Core migrations for schema changes
5. **Update signing keys** — Replace development signing credentials with production keys
6. **Test** — Verify everything works end-to-end

### Additional considerations for your setup:
- **EF Core stores**: Create new migrations for the updated schema
- **ASP.NET Identity**: Update the ASP.NET Identity integration package
- **Reverse proxy**: Ensure forwarded headers are configured correctly
- **Discovery document**: Check `/.well-known/openid-configuration` after migration
- **Token issuance**: Test that tokens are issued and validated correctly
