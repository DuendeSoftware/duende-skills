No. Migration guides for IdentityServer4 → Duende apply to ASP.NET Core-based IdentityServer4. IdentityServer3 is a different codebase for .NET Framework/OWIN/Katana, with a different architecture, different APIs (e.g. `IdentityServerServiceFactory`, `IdentityServerOptions`, `UseIdentityServer` on `IAppBuilder`), different data stores, and different configuration models (clients/scopes).

Recommended path:
1. Migrate IdentityServer3 → IdentityServer4 (or directly to Duende) as a rewrite/port. Scopes in IS3 combine identity/resource scopes; they need splitting into IdentityResources, ApiScopes and ApiResources.
2. Move to modern .NET (Duende v7 requires .NET 8+); .NET Framework 4.8 isn't supported by Duende IdentityServer.
3. Port custom services (user service → `IProfileService`/`IResourceOwnerPasswordValidator`), stores, and UI (views/controllers) manually.
4. Migrate stored data (clients, secrets, grants) with scripts; signing keys can be carried over to avoid invalidating tokens. Refresh tokens/consents may need re-issuing.
5. Then use Duende's documentation for general configuration, license, and deployment.

So you can use the guide only for the later steps, not as a direct upgrade path.
