I don't know of "Duende Storage" as a replacement for the EF Core stores, and I'm not aware of any announcement deprecating `AddConfigurationStore`/`AddOperationalStore`. If it exists as a newer option, I can't vouch for its details.

**Recommendation: don't migrate just because something new exists.** Your EF-based setup is supported, works, and is well documented. Migration has real risk: schema differences, re-encoding of secrets, and invalidation of active grants and sessions.

Migrate only if you have a concrete need, such as a feature only the new approach offers, a database you can't get with EF, or an end-of-support notice. Before deciding:
1. Read the official release notes and docs for the stated direction.
2. Check whether the new option supports your databases.
3. Check whether a data migration path exists.
4. Try it in a staging copy first.

If you do migrate, take backups, plan for existing refresh tokens and sessions, and keep a rollback path.
