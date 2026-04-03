# Pre-Migration Analysis

Before migrating to Duende IdentityServer, you should audit your current IdentityServer4 configuration. Some things to check:

- Which version of IdentityServer4 are you running?
- What .NET version are you targeting?
- How many clients do you have?
- What authentication schemes are configured?
- How are your signing keys managed?

You could write a simple diagnostic endpoint that reports on these items. Check your `Startup.cs` configuration and client store to understand what you're working with.

I'd recommend:
1. Document your current configuration
2. List all clients and their grant types
3. Check your database schema version
4. Review your signing key setup
5. Test your current token issuance to have a baseline
