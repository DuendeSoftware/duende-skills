I can't verify the specifics of an IdentityServer 8.1 preview, so I can't name the replacement API with certainty; check the 8.1 release notes/upgrade guide and the text of the `[Obsolete]` message, which normally names the replacement. 

What I can say:
- An obsolete warning on one method does **not** mean EF Core is deprecated. Typically Duende renames or restructures registration APIs (e.g. a new unified builder/extension for stores) while the EF Core store package stays supported.
- Practical steps: read the warning text (it usually points to the new method), keep `Duende.IdentityServer.EntityFramework` as-is, make the change in your `AddIdentityServer()` chain, and re-run builds. Until then the obsolete method still works; it's a warning, not an error.
- Existing migrations and database schema should be unaffected, but run `dotnet ef migrations add` after upgrading to see if any schema changes occurred.

Current (8.0) form for reference:
```csharp
.AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs, s => s.MigrationsAssembly(asm)))
```
