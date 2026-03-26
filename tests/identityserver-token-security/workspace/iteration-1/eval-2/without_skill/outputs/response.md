# Validating DPoP at the API

To validate DPoP tokens in your API, you need to configure JWT bearer authentication with DPoP support.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

// Enable DPoP validation
builder.Services.ConfigureDPoPTokensForScheme("token");

// Cache for replay detection
builder.Services.AddDistributedMemoryCache();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

You'll need to install a package that provides DPoP support for ASP.NET Core JWT bearer authentication. The DPoP validation checks that the proof JWT matches the token's bound key and prevents replay attacks using the distributed cache.
