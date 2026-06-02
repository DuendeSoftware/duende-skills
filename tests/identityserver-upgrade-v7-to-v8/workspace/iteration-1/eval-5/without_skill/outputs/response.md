# IAuthorizationParametersMessageStore in v8

If `IAuthorizationParametersMessageStore` has been removed in IdentityServer v8, you'll need to find an alternative approach for handling large authorization requests.

## Possible Alternatives

### Option 1: Re-implement a Custom Solution

You could create a custom middleware or endpoint that stores authorization parameters and redirects with a reference:

```csharp
public class AuthParameterStore
{
    private readonly IDistributedCache _cache;

    public async Task<string> StoreAsync(AuthorizationRequest request)
    {
        var id = Guid.NewGuid().ToString();
        await _cache.SetStringAsync(id, JsonSerializer.Serialize(request),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) });
        return id;
    }
}
```

### Option 2: Use Pushed Authorization Requests (PAR)

If v8 supports PAR (RFC 9126), this would be the standard way to handle large authorization requests:

1. Client pushes authorization parameters to the server
2. Server returns a request_uri reference
3. Client uses the request_uri in the authorization redirect

Check if v8 has built-in PAR support, as this is becoming the standard approach for this problem.

### Option 3: Use Request Objects (JAR)

JWT-Secured Authorization Requests (RFC 9101) allow passing parameters as a signed JWT, which can be passed by reference.

## Recommendation

Check the v8 migration guide for the officially recommended replacement pattern.
