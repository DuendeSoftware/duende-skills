# Configuring DPoP Validation in the API

To validate DPoP proof tokens in your API, you need to set up JWT Bearer authentication and add DPoP support.

## Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.TokenValidationParameters.ValidateAudience = false;

        // Enable DPoP inside the JWT Bearer configuration
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

## DPoP Validation

For DPoP validation, you'll need to add middleware or a custom handler that:

1. Extracts the `DPoP` header from the request
2. Validates the DPoP proof JWT signature
3. Checks that the `cnf` claim in the access token matches the key in the proof
4. Validates the HTTP method and URL in the proof match the request

You may want to check if there's an official Microsoft or community package for ASP.NET Core DPoP validation, as implementing this from scratch involves several security-sensitive steps.

## Caching for Replay Detection

Add a cache to prevent DPoP proof replay:

```csharp
builder.Services.AddDistributedMemoryCache(); // Or Redis for production
```

## Notes

- DPoP proofs include a `jti` claim that should be tracked to prevent replay
- The proof token has a short lifetime and is bound to the HTTP method and URL
- Consider using a library that handles the DPoP validation details
