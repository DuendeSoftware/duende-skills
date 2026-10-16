# What gets cleaned up

## On logout
`SignOutAsync` removes the IdentityServer cookie and, when server-side sessions are enabled, the session record. By default it does **not** do more:

| Artifact | Default at logout | How to clean up |
|---|---|---|
| IdentityServer cookie | Removed | n/a |
| Server-side session record | Removed automatically | n/a |
| External IdP session | Not signed out | external logout flow |
| Client app sessions | Not cleaned unless notified | front/back-channel logout |
| Refresh tokens & reference access tokens | **Kept** | `CoordinateLifetimeWithUserSession` on the client, or global `Authentication.CoordinateClientLifetimesWithUserSession` (client value wins; no server-side sessions required) |
| JWT access tokens | Never revoked; expire on their own | keep lifetime short |
| Consents / other grants | Kept | `ISessionManagementService` / `IPersistedGrantService` (coordination doesn't revoke consents) |
| BFF session + refresh token | Refresh token revoked by default on BFF logout | n/a |

## When a server-side session just expires
- Clients with a **coordinated lifetime** get their refresh/reference tokens revoked and receive a **back-channel logout**.
- Other clients in the session are notified only if `ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true` (default `false`).
- JWT access tokens still live until they expire.
- The expired record is removed by the cleanup job (`RemoveExpiredSessions`, default every 10 minutes, batch 100).

## Admin-initiated termination
`ISessionManagementService.RemoveSessionsAsync` removes the session, sends back-channel logout, revokes tokens and revokes consents by default; each can be switched off via `RemoveServerSideSession`, `SendBackchannelLogoutNotification`, `RevokeTokens`, `RevokeConsents`.
