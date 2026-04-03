# DPoP Support for APIs

DPoP (Demonstration of Proof-of-Possession) is a mechanism to bind tokens to a cryptographic key. The client sends a DPoP proof along with the access token.

## Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        // You would need to add DPoP validation in the token validation events
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                // Check for DPoP proof header and validate it
                var dpopHeader = context.HttpContext.Request.Headers["DPoP"].FirstOrDefault();
                if (dpopHeader != null)
                {
                    // Validate the DPoP proof JWT
                    // Check cnf claim matches proof key
                }
                return Task.CompletedTask;
            }
        };
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

DPoP is relatively new and you may need additional libraries or custom middleware to fully validate the proof. The validation involves checking the proof JWT signature, HTTP method/URL binding, and nonce freshness.
