# External Authentication Providers After Migration

## Package Updates Required

Your external authentication handlers need to be updated for .NET 8:

### Google OAuth
The Google authentication package is part of ASP.NET Core. On .NET 8, it's included in the framework:
```csharp
builder.Services.AddAuthentication()
    .AddGoogle(options => { /* same config */ });
```

### WS-Federation
Update the WS-Federation NuGet package to match .NET 8:
```xml
<PackageReference Include="Microsoft.AspNetCore.Authentication.WsFederation" Version="8.0.0" />
```

### Sustainsys.Saml2
Check for a .NET 8 compatible version of Sustainsys.Saml2. This is a third-party library that may need updating.

## Testing

After migration, make sure to test all external login flows to verify they still work correctly. Authentication handler issues typically manifest at runtime rather than compile time.
