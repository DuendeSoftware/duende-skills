# Fix: shared state across instances

Two things are per-instance by default:

1. **Data Protection keys** – the auth cookie is encrypted with keys that differ on each node. Share them:
```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("MyBff")
    .PersistKeysToDbContext<MyKeysContext>(); // or Redis / Azure Blob + ProtectKeysWithAzureKeyVault
```
2. **Server-side sessions** – if used, the default store is in-memory. Use the EF store:
```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(o => { ... })
    .AddEntityFrameworkServerSideSessions(o => o.UseSqlServer(cs));
```
Also the OIDC correlation/nonce cookies need the same Data Protection keys, since the callback may land on another node. Sticky sessions are an alternative workaround but not recommended.
