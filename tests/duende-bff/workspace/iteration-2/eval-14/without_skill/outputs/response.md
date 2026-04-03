If you want to bypass the BFF's automatic response handling and trigger a real OIDC redirect, you'll need to configure the endpoint to not suppress the authentication challenge.

In BFF, endpoints typically return 401 status codes for API clients to handle. To trigger a redirect instead:

```csharp
app.MapGet("/api/interactive", () =>
{
    return Results.Ok("data");
})
.RequireAuthorization();
```

You might need to look into the BFF middleware configuration to disable the response suppression for specific endpoints. There might be an option like `.SkipResponseHandling()` or similar on the endpoint configuration.

The general approach would be:
1. Keep the endpoint marked as requiring authorization
2. Disable the BFF response transformation that converts redirects to 401s
3. Let ASP.NET Core's default challenge behavior redirect to the IDP
