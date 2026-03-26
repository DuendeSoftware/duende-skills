# Users Randomly Logged Out in Load-Balanced BFF

The problem is likely that your authentication cookies can't be read across instances. ASP.NET Core uses Data Protection to encrypt cookies, and by default each instance has its own key ring.

## Fix

You need to share the Data Protection keys:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/shared/keys"))
    .SetApplicationName("my-bff");
```

Or use a database:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>();
```

You should also consider using a distributed session store (like Redis or SQL Server) so that sessions are shared across instances.
