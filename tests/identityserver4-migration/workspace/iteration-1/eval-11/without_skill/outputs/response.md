# Migrating from IdentityServer3 to Duende IdentityServer

Unfortunately, you can't directly use a standard IdentityServer4-to-Duende migration guide for your IdentityServer3 project. IdentityServer3 is a significantly different product that was built for .NET Framework using OWIN/Katana, whereas Duende IdentityServer (and IdentityServer4 before it) is built on ASP.NET Core.

## Key Differences

- **IdentityServer3**: Runs on .NET Framework with OWIN/Katana middleware pipeline
- **IdentityServer4**: Runs on ASP.NET Core with its middleware pipeline
- **Duende IdentityServer**: Successor to IdentityServer4, also ASP.NET Core

These are different products with different APIs, configuration models, and hosting approaches.

## Recommended Approach

You'll need to do a two-phase migration:

1. **First, migrate from IdentityServer3 to IdentityServer4 on ASP.NET Core**
   - This involves porting your application from .NET Framework to ASP.NET Core
   - Rewrite the OWIN/Katana middleware configuration to ASP.NET Core middleware
   - Update client and scope configurations to IdentityServer4's API
   - Migrate your data stores

2. **Then, migrate from IdentityServer4 to Duende IdentityServer**
   - This second step is much simpler — primarily namespace and package changes
   - Use the standard IS4-to-Duende migration guide for this phase

The first step is the more challenging one, as it requires a platform migration from .NET Framework to .NET Core/ASP.NET Core in addition to the IdentityServer API changes.

I'd recommend planning this as a significant project and potentially running both versions in parallel during the transition period.
