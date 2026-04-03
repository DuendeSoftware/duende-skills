To host DCR separately from your main IdentityServer, you'd need to create a new ASP.NET Core application that handles the registration endpoint while sharing data with the main IdentityServer.

### Separate DCR Service — Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add authentication to validate tokens from the main IdentityServer
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "dcr-api";
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("DcrPolicy", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "dcr:manage");
    });
});

// Add a shared database context for client storage
builder.Services.AddDbContext<ClientDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("IdentityDb")));

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// Custom DCR endpoint
app.MapPost("/connect/register", async (ClientDbContext db, HttpContext context) =>
{
    var request = await context.Request.ReadFromJsonAsync<DcrRequest>();
    
    // Validate and create client
    var client = new ClientEntity
    {
        ClientId = Guid.NewGuid().ToString(),
        ClientName = request.ClientName,
        // Store client details...
    };
    
    db.Clients.Add(client);
    await db.SaveChangesAsync();
    
    return Results.Ok(new { client_id = client.ClientId });
}).RequireAuthorization("DcrPolicy");

app.Run();
```

### Important considerations

- The DCR service must share the same database as IdentityServer so that registered clients are visible to both
- Use JWT bearer authentication pointing to your main IdentityServer for token validation
- Secure the registration endpoint with proper authorization
- You'll need to implement the client storage logic to match IdentityServer's expected data format
- Consider implementing a proper DCR request/response format per RFC 7591
