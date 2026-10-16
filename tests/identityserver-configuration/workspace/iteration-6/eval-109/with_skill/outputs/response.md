**Scope parser** (subclass `DefaultScopeParser`, override `ParseScopeValue(ParseScopeContext)`):

```csharp
using Duende.IdentityServer.Validation;

public class ParameterizedScopeParser : DefaultScopeParser
{
    public ParameterizedScopeParser(ILogger<DefaultScopeParser> logger) : base(logger) { }

    public override void ParseScopeValue(ParseScopeContext scopeContext)
    {
        const string name = "transaction";
        const string separator = ":";
        const string prefix = name + separator;

        var value = scopeContext.RawValue;

        if (value.StartsWith(prefix))
        {
            var parts = value.Split(separator, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 2)
                scopeContext.SetParsedValues(name, parts[1]);
            else
                scopeContext.SetError("transaction scope missing transaction parameter value");
        }
        else if (value != name)
        {
            base.ParseScopeValue(scopeContext);
        }
        else
        {
            scopeContext.SetIgnore(); // bare "transaction" isn't valid
        }
    }
}
```
**Registration**:
```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[] { new ApiScope("transaction") });

idsvrBuilder.AddScopeParser<ParameterizedScopeParser>();
idsvrBuilder.AddProfileService<MyProfileService>();
```
The base `transaction` ApiScope must exist, since the parsed name is resolved against it; clients need `transaction` in `AllowedScopes`.

**Reading it in `IProfileService`**:
```csharp
public class MyProfileService : IProfileService
{
    public Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var transaction = context.RequestedResources.ParsedScopes
            .FirstOrDefault(x => x.ParsedName == "transaction");

        if (transaction is not null)
        {
            // "abc123" for scope "transaction:abc123"
            context.IssuedClaims.Add(new Claim("transaction_id", transaction.ParsedParameter));
        }
        return Task.CompletedTask;
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```
`ParseScopeContext` exposes `RawValue`, `ParsedName`, `ParsedParameter`, `Error`, `Ignore`, `Succeeded` plus `SetParsedValues`, `SetIgnore`, `SetError`. `ParsedScopes` is on `RequestedResources`.
