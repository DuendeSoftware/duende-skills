# Adding DPoP proof-of-possession validation to a JWT bearer API

DPoP (Demonstrating Proof of Possession, RFC 9449) sender-constrains an access token to a key held by the client. On each call the client sends:

- the access token in `Authorization: DPoP <token>` (note the `DPoP` scheme, not `Bearer`), and
- a freshly signed proof JWT in the `DPoP` request header.

The API must (1) parse the proof JWT, (2) verify its signature with the embedded public JWK, (3) confirm the JWK thumbprint matches the `cnf.jkt` claim in the access token, (4) check `htm`/`htu`/`iat` bind the proof to this request, and (5) reject replays using the `jti`.

## Recommended approach

DPoP validation is intricate and easy to get wrong by hand, so use a maintained library rather than rolling your own. With IdentityServer/Duende, the introspection/JwtBearer integration packages provide DPoP support; otherwise you can implement an `OnTokenValidated`/`OnMessageReceived` hook.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// A store for replay detection (jti values already seen)
builder.Services.AddDistributedMemoryCache();

builder.Services.AddAuthentication("token")
    .AddJwtBearer("token", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "api1";

        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // Accept the DPoP auth scheme instead of Bearer
                var header = context.Request.Headers.Authorization.ToString();
                if (header.StartsWith("DPoP ", StringComparison.OrdinalIgnoreCase))
                {
                    context.Token = header["DPoP ".Length..].Trim();
                }
                return Task.CompletedTask;
            },
            OnTokenValidated = async context =>
            {
                // 1. Read the DPoP proof header
                var proof = context.Request.Headers["DPoP"].ToString();
                // 2. Validate proof signature, htm/htu/iat, and match cnf.jkt
                // 3. Check jti against the distributed cache for replay
                // (implement using your DPoP helper of choice)
                await Task.CompletedTask;
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

## Key points

- Use a distributed cache (`AddDistributedMemoryCache`, or Redis in production) to track seen `jti` values for replay protection.
- If the proof is missing or stale, respond `401` with `WWW-Authenticate: DPoP error="use_dpop_nonce"` and a `DPoP-Nonce` header so the client retries.
- Prefer a well-tested DPoP library over hand-rolled cryptography.

If you're on the Duende stack, check their JwtBearer integration package for built-in DPoP support that wires all of this up for you.
