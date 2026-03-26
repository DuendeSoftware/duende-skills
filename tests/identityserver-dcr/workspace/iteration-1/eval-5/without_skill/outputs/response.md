# Persistent Store for DCR Clients

For production, use Entity Framework:

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```

This uses EF Core to persist dynamically registered clients to your database. Make sure you have the configuration store DbContext set up with migrations.

Don't use in-memory stores in production as clients will be lost on restart.
