I don't know of a "Duende Storage" schema-validated extended-properties feature, so I can't show its API. As a general approach, with the EF Core store you'd model this yourself:

- Clients have a `Properties` dictionary (`Client.Properties["cost_center"] = "1234"`), where values are strings, so there is no built-in integer type or schema validation.
- Add validation in your admin API: parse and range-check the value before saving.

```csharp
public record ClientDto(string ClientId, int CostCenter);

app.MapPut("/admin/clients/{id}", async (string id, ClientDto dto, ConfigurationDbContext db) =>
{
    if (dto.CostCenter <= 0) return Results.BadRequest("cost_center must be a positive integer");
    var client = await db.Clients.Include(c => c.Properties).SingleOrDefaultAsync(c => c.ClientId == id);
    if (client is null) return Results.NotFound();
    var p = client.Properties.FirstOrDefault(x => x.Key == "cost_center");
    if (p is null) client.Properties.Add(new() { Key = "cost_center", Value = dto.CostCenter.ToString() });
    else p.Value = dto.CostCenter.ToString();
    await db.SaveChangesAsync();
    return Results.NoContent();
}).RequireAuthorization("admin");
```
If you need real JSON-schema-style validation defined in code, check the Duende docs for a dedicated feature, since I can't verify one.
