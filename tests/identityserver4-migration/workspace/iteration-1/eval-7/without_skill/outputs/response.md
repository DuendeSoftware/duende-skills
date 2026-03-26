# Persisted Grants Decryption Issue After .NET Upgrade

## The Problem

This is a **Data Protection** issue. ASP.NET Core Data Protection is used to encrypt sensitive data in persisted grants. When you upgrade .NET versions, the Data Protection configuration may change, causing previously encrypted data to become unreadable.

## Why It Happens

The Data Protection system uses an application discriminator to isolate keys between different applications. By default, this is based on the content root path of the application. When the .NET version changes, the way this path is determined can change slightly, causing the system to treat the new version as a different application.

## Fix

Set an explicit application name for Data Protection:

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("MyIdentityServer");
```

This ensures consistent key isolation across .NET version upgrades.

## Also Check

Make sure the old Data Protection keys are still accessible. If they've been deleted or rotated away, the old encrypted data cannot be recovered, and affected users will need to re-authenticate.
