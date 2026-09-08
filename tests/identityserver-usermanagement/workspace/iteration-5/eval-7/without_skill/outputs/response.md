# Diagnosing Storage Configuration at the Top Level

Without the exact error text I can't be 100% certain, but the symptom you describe — storage configured at the top level, outside the user-management registration, and then failures — is a classic **configuration-scoping** problem with fluent builder APIs. Here's how I'd reason about it and fix it.

## Likely Cause: Config Attached to the Wrong Object

Many of these `AddXxx(options => { ... })` registrations expect their sub-configuration (like the storage provider) to be set up **inside the options callback**, so that the feature can wire the store into its own service registrations and internal options. If you register the store on the top-level `builder.Services` (or on the wrong builder), the user-management component may never see it, and it fails when it tries to resolve its store at startup.

**Try moving the storage call inside the options lambda:**

```csharp
builder.Services.AddIdentityServer(/* ... */)
    .AddInMemoryClients(Config.Clients)
    .AddUserManagement(options =>
    {
        // storage configured HERE, inside the callback
        options.AddSqliteStore("Data Source=users.db");
    });
```

rather than:

```csharp
builder.Services.AddUserManagement(/* ... */);
builder.Services.AddSqliteStore("Data Source=users.db"); // likely wrong scope
```

## Other Things to Check

1. **Registration order** — make sure the store is registered before anything that depends on it resolves, and that you're calling it on the object the docs specify (the options/builder returned by the feature, not the root service collection).
2. **Service resolution errors** — if the message is something like "Unable to resolve service for type ...", that confirms the store wasn't registered where the component looks for it.
3. **Connection string / provider package** — confirm the matching storage NuGet package is installed and the connection string is valid.
4. **Database schema exists** — if the registration is fine but you get errors at first use, the tables may not have been created yet; ensure whatever schema-initialization or migration step the product provides has run.

## Recommendation

Move the storage configuration **inside** the user-management options callback (as shown above), then re-run. If that doesn't resolve it, share the exact exception message and stack trace and check the product documentation for the precise object the storage extension method is meant to be called on — the fluent APIs are picky about scope, and the fix is almost always "configure it in the right place," not a change to the storage provider itself.
