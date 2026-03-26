# Adding DPoP Support to Your API

DPoP (Demonstration of Proof-of-Possession) adds an extra layer of security by binding tokens to cryptographic keys.

## Configure DPoP

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // Configure DPoP validation
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // Check for DPoP header and validate proof
                var dpopHeader = context.Request.Headers["DPoP"].FirstOrDefault();
                if (!string.IsNullOrEmpty(dpopHeader))
                {
                    // Validate DPoP proof JWT
                    // This requires custom validation logic
                }
                return Task.CompletedTask;
            }
        };
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();
```

## Notes

DPoP validation involves checking that the proof JWT in the DPoP header matches the key thumbprint in the access token's `cnf` claim. You'll need to implement custom validation logic or use a library that supports DPoP.

For production use, consider using a library that provides built-in DPoP support rather than implementing the validation manually.
