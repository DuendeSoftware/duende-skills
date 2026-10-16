I'm not familiar with `AddDynamicSchemas()` or `AddSamlDynamicProvider()` as documented APIs, so this is an informed guess rather than a confirmed answer.

The likely cause: when schemas become runtime-editable and are stored in the database, the validator reads the *stored* schema, not the code-registered one. `AddSamlDynamicProvider()` probably registers the SAML provider type and its schema in code, but with dynamic schemas that code registration may no longer seed or extend the stored schema. So extended properties on the SAML provider aren't in the active schema and fail validation as unknown.

What to try:
- Check whether the SAML provider type's schema exists in the dynamic schema store, and whether the extended properties are defined there.
- Add or update the extended property definitions through the schema admin API.
- Check registration order, and whether there is a seeding or merge option for code-defined schemas.
- Turn on debug logging to see the exact validation error.
