# Deleting and restoring a tenant's space

I can't confirm Spaces' exact delete semantics from memory, so here's what to verify and how to design it.

## What happens to the data
It depends on soft vs. hard delete:
- **Soft delete** (recommended): the space is marked deleted/disabled. Its clients, grants, keys and users remain in storage but all requests return 404/disabled and tokens stop being issued. Restore flips the flag and everything returns, though refresh tokens and sessions may have expired meanwhile, and issued access tokens may have lapsed.
- **Hard delete**: configuration, persisted grants and keys are removed. A "restore" then means recreating from backup, and new signing keys mean old tokens cannot validate.

Questions to settle: are users in a shared database deleted (they are likely not, unless scoped by tenant)? Is there a retention window, after which a purge job hard-deletes? Do backups contain tenant data (GDPR erasure implications)?

## Who should be allowed
- Never tenant admins or ordinary end users; destructive lifecycle operations belong to **platform/operator administrators** only.
- Put them behind a dedicated admin API with strong auth (MFA, a specific scope/role such as `spaces.admin`), not exposed on the public tenant endpoints.
- Require two-person approval or customer-verified request for delete/restore, plus confirmation of the exact tenant ID.
- Audit log every action (who, when, tenant, reason) and alert on it.
- Prefer a soft-delete grace period before purge, and test restore regularly.
