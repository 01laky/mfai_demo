# ACL & capabilities module

## What it is

Server-driven **permission strings** and **`GET /{face}/api/me/capabilities`** so SPAs do not infer authz only from JWT role names.

## Where in the repo

| Layer | Location |
|-------|----------|
| Permission catalog | `be_demo/BeDemo.Api/Security/AclPermissionKeys.cs` |
| Capabilities response | `be_demo/BeDemo.Api/Services/AccessCapabilitiesService.cs`, `Models/DTOs/CapabilitiesResponse.cs` |
| HTTP | `be_demo/BeDemo.Api/Controllers/MeController.cs` |
| FE (mirror) | `fe_demo/src/acl/*`, `src/api/meCapabilitiesClient.ts`, `src/hooks/api/useMeCapabilities.ts` |
| Admin (mirror) | `admin_demo/src/acl/*`, same client/hook pattern |

## Full reference

→ [`../guides/acl-and-capabilities.md`](../guides/acl-and-capabilities.md) (keys, gates, tests, integration users).
