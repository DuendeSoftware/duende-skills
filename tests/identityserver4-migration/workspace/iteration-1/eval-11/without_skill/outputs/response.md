# IdentityServer3 to Duende IdentityServer Migration

## Not Directly Supported

The IdentityServer4-to-Duende migration guide does **not** cover IdentityServer3. IdentityServer3 ran on **.NET Framework with OWIN/Katana**, which is a completely different hosting stack from ASP.NET Core.

## What You Need to Do

You'll need to migrate in stages:

1. **First**: Port from IdentityServer3 (.NET Framework/OWIN) to IdentityServer4 (ASP.NET Core). This involves rewriting your hosting, middleware, and configuration since the APIs are completely different.

2. **Then**: Migrate from IdentityServer4 to Duende IdentityServer using the standard migration guide.

The first step is the big one — moving from .NET Framework to .NET Core is a significant effort that goes beyond just IdentityServer.
