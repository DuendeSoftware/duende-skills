# Configuring IdentityServer Options

Here's how to configure the IdentityServer options as requested:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
});

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Explanation

- `IssuerUri` sets the issuer value in tokens and the discovery document.
- `EmitScopesAsSpaceDelimitedStringInJwt` changes how scopes appear in JWT tokens — as a space-delimited string instead of an array.

For the license key, you'd typically set it in the options:

```csharp
options.LicenseKey = "your-license-key-here";
```

For data protection in multi-instance deployments, you should configure shared key storage so all instances can read the same encrypted data.
