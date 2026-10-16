# `IProfileService` and `context.Client` in v8

I can't verify the v8 signature. Here is my best understanding.

In v7, `ProfileDataRequestContext.Client` and `IsActiveContext.Client` are non-nullable `Client`. In v8 they are probably **nullable** (`Client?`) as part of the nullable-reference-types work. The new runtime case is that **`Client` can be null**, for example when the profile service is invoked without a client context (such as an `IsActiveAsync` call from a session check or a back-channel flow with no specific client). Code that compiles on v7 then gives CS8602 warnings, or errors with warnings-as-errors, and can throw `NullReferenceException` at runtime.

```csharp
public async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var clientId = context.Client?.ClientId;
    if (clientId is null)
    {
        // no client: return only client-independent claims
    }
    ...
}

public async Task IsActiveAsync(IsActiveContext context)
{
    var clientId = context.Client?.ClientId;
    context.IsActive = await _users.IsActiveAsync(context.Subject.GetSubjectId());
}
```
Decide what you want when the client is null: fall back to default claims, and don't make `IsActive` depend on client-specific rules in that case.
