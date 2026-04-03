# IdentityServer3 Migration

IdentityServer3 on .NET Framework 4.8 with OWIN/Katana is quite old. Migrating directly to Duende IdentityServer would be a significant effort since they're built on very different platforms.

IdentityServer3 uses OWIN/Katana on .NET Framework, while Duende IdentityServer runs on ASP.NET Core. You'll essentially need to rewrite your identity server from scratch on ASP.NET Core.

## Recommended Approach

1. First, migrate from .NET Framework to .NET Core/ASP.NET Core
2. Port your IdentityServer3 configuration to IdentityServer4 on ASP.NET Core
3. Then upgrade from IdentityServer4 to Duende IdentityServer

This is a multi-step process and a standard migration guide for IdentityServer4 to Duende won't directly apply to your IdentityServer3 setup since they have fundamentally different APIs and hosting models.
