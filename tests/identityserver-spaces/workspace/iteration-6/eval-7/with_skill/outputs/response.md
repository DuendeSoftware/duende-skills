# Deleting and restoring a space

## What happens to the data
Deleting a space is a **soft delete**: the space's pool data is **blocked but retained**. Its configuration and operational data (clients, grants, sessions) are not destroyed; requests to the space stop resolving (404) and nothing is served from it. `ISpaceAdmin.UndeleteAsync` **restores the space and its match rules**, and the retained data is visible again.

```csharp
var admin = sp.GetRequiredService<ISpaceAdmin>();
// delete (soft)
await admin.DeleteAsync(spaceId, ct);
// restore later
await admin.UndeleteAsync(spaceId, ct);
```
(Check the exact signatures in the preview package.)

Practical implications:
- Because data is retained, a restore returns the tenant's clients and grants; but time-limited items (sessions, refresh tokens, codes) may have expired meanwhile.
- Soft delete is not erasure: if the customer expects data removal (e.g. GDPR), you need a separate, documented purge process.
- User data stored through `IStorageFactory` (e.g. Duende User Management) is per space and follows the same lifecycle; shared user databases, caches, Data Protection keys and signing keys are **not** covered by Spaces and need their own handling.
- Moving a space to a different pool changes which data it sees, so never do that as part of a restore without care.

## Who should be allowed
Treat delete, undelete and pool reassignment as **security-boundary changes**:
- Only trusted platform operators via a provisioning/admin path (not tenant admins, not public endpoints).
- Authorize admins **per space**, with a break-glass approach (strong auth/MFA, approval).
- **Audit** every action: who, which space, when, why.
- Run provisioning/admin operations from one deployment process to avoid races, and verify customer identity before restoring.
