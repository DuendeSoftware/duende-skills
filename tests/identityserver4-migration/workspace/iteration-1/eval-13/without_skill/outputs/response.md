# Pre-Migration Analysis for IdentityServer4

## Planning Your Migration

Before migrating, it's a good idea to assess your current IdentityServer4 setup. You should document:

- Your current .NET version and IdentityServer4 version
- How many clients you have configured
- What authentication schemes are registered
- How signing keys are configured
- Your data protection configuration

## Duende Migration Resources

Duende Software provides migration documentation and resources to help plan the upgrade. Check their documentation site for the latest guidance on upgrading from IdentityServer4.

You could also review your current configuration programmatically by examining your DI container and configuration at runtime, checking things like:
- Registered authentication handlers
- Client store configuration
- Signing credential setup
