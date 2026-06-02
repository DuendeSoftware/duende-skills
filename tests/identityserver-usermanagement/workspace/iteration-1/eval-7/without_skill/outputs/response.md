# Troubleshooting Storage Configuration Issues

If your storage configuration is at the top level of Program.cs and you're getting errors, the issue likely depends on how you're trying to register the storage provider.

## Common Issues

### 1. DbContext Not Registered

If you're using Entity Framework Core and your DbContext isn't registered before Identity tries to use it:

```csharp
// Make sure DbContext is registered before AddIdentity
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite("Data Source=users.db"));

builder.Services.AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>();
```

### 2. Service Registration Order

The order of service registration matters. Ensure your storage/database services are registered before anything that depends on them:

```csharp
// 1. First, register the database
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite("Data Source=users.db"));

// 2. Then, register Identity with the store
builder.Services.AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// 3. Finally, configure IdentityServer
builder.Services.AddIdentityServer()
    .AddAspNetIdentity<IdentityUser>()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

### 3. Missing Migrations

If the database doesn't exist or is missing tables:

```bash
dotnet ef migrations add InitialCreate
dotnet ef database update
```

## Summary

- Register storage (DbContext) before identity services.
- Run EF migrations to create the database schema.
- Check that connection strings are correct in your configuration.
