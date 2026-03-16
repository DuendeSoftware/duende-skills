# Persisted Grants Decryption Failure After Upgrade

## Likely Cause: Data Protection Keys

The most likely cause is an **ASP.NET Core Data Protection** issue. IdentityServer encrypts persisted grant data using the Data Protection system. If the Data Protection keys or configuration changed during your upgrade, previously encrypted data cannot be decrypted.

## Common Reasons

1. **Data Protection keys were lost**: If you were storing Data Protection keys in the default location (file system or in-memory), upgrading the application may have changed the storage path or the keys may not have been carried over to the new deployment.

2. **Application isolation changed**: Data Protection uses an application discriminator to isolate keys between applications. If the hosting environment changed (different path, different app pool, etc.), the framework may treat it as a different application.

## How to Fix

1. **Set an explicit application name** to ensure key isolation remains consistent:
   ```csharp
   builder.Services.AddDataProtection()
       .SetApplicationName("MyIdentityServer")
       .PersistKeysToFileSystem(new DirectoryInfo(@"C:\keys"));
   ```

2. **Ensure old keys are still available**: Copy or point to the Data Protection key ring from your old deployment. The keys are typically stored as XML files.

3. **Use a persistent key store**: For production, store Data Protection keys in a database or Azure Blob Storage so they survive deployments:
   ```csharp
   builder.Services.AddDataProtection()
       .PersistKeysToDbContext<MyDbContext>();
   ```

4. **Verify the key ring**: Check that the key XML files or database entries from the old deployment still exist and are accessible to the new application.

If the old keys are truly lost, the encrypted persisted grants unfortunately cannot be recovered. Users will need to re-authenticate.
