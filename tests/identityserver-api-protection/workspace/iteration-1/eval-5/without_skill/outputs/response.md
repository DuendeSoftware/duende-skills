# Adding DPoP Support to Your API

DPoP (Demonstration of Proof-of-Possession) adds an extra layer of security by binding tokens to a client's key pair. Here's how to set it up.

## Configure JWT Bearer with DPoP

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";
        
        // Add DPoP validation via events
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // Look for DPoP token in the DPoP header
                var dpopToken = context.Request.Headers["DPoP"].FirstOrDefault();
                if (!string.IsNullOrEmpty(dpopToken))
                {
                    // Validate DPoP proof...
                    context.Token = context.Request.Headers.Authorization
                        .FirstOrDefault()?.Replace("DPoP ", "");
                }
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapGet("/data", () => Results.Ok(new { message = "Protected data" }))
    .RequireAuthorization();

app.Run();

public record DataModel(int Id, string Name, string Description);
```

## How DPoP Works

DPoP requires the client to:
1. Generate a key pair
2. Include a proof JWT in the `DPoP` HTTP header
3. The proof binds the token to a specific HTTP method and URL

The API validates that the access token's key thumbprint matches the proof JWT's key, ensuring the token can only be used by the original client.

Note: Full DPoP implementation is complex and involves proof JWT validation, nonce management, and key binding verification. You may want to use a library that handles the details.
