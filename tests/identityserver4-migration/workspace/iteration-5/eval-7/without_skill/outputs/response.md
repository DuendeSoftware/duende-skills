# Why your persisted grants stopped decrypting after the .NET upgrade

## It's ASP.NET Core Data Protection, not IdentityServer

IdentityServer encrypts sensitive values in the operational store — including the payload of persisted grants — using **ASP.NET Core Data Protection**. Data Protection can only decrypt something if it uses the same **key ring** and the same **application discriminator** that were used to encrypt it. Your upgrade changed the discriminator, so the runtime now treats the protected data as belonging to a "different" application and refuses to unprotect it.

## The application name changed under you

When you don't configure Data Protection explicitly, it derives a per-application isolation key ("application name") automatically. In a typical web app that default is based on the **content root path** of the application. Details of how that default is computed have shifted between .NET releases, so an app that ran on .NET 6 can end up with a different computed application name once it runs on .NET 8. Same keys on disk, but a different discriminator — and that's enough to break decryption of everything that was protected before the upgrade (persisted grants, auth cookies, antiforgery tokens, etc.).

## How to fix it

**Pin the application name explicitly** so it no longer depends on the framework default:

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("my-identityserver")   // fixed, doesn't change across upgrades
    .PersistKeysToDbContext<MyKeysDbContext>(); // or file system / blob storage
```

Set it to a stable string and keep it constant across deployments and framework upgrades.

**Make sure the original keys are still there.** `SetApplicationName` only recovers the data if the key ring that did the original encryption is still available. Point Data Protection at the same persistent key store you were using before the upgrade, and don't delete or rotate those keys away — if they're gone, the old encrypted data can't be recovered. (And if you were previously relying on the default in-memory key store, the keys were regenerated on restart, which is a separate problem.)

Once the application name is pinned and the old keys are accessible again, your existing persisted grants will decrypt normally.
