var builder = WebApplication.CreateBuilder(args);

// TODO: Configure authentication (cookie + OIDC)
// TODO: Configure token management
// TODO: Register HTTP clients for API calls

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => "Hello World");

app.MapGet("/call-api", async (IHttpClientFactory httpClientFactory, CancellationToken ct) =>
{
    // TODO: Call the invoice API using a properly configured HTTP client
    return Results.Ok("Not implemented");
});

app.Run();
