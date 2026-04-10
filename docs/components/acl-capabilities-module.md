# ACL & capabilities module

## What it is

Server-driven **permission strings** and **`GET /{face}/api/me/capabilities`** so SPAs do not infer authz only from JWT role names.

## Where in the repo

| Layer                 | Location                                                                                          |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| Permission catalog    | `be_demo/BeDemo.Api/Security/AclPermissionKeys.cs`                                                |
| Capabilities response | `be_demo/BeDemo.Api/Services/AccessCapabilitiesService.cs`, `Models/DTOs/CapabilitiesResponse.cs` |
| HTTP                  | `be_demo/BeDemo.Api/Controllers/MeController.cs`                                                  |
| FE (mirror)           | `fe_demo/src/acl/*`, `src/api/meCapabilitiesClient.ts`, `src/hooks/api/useMeCapabilities.ts`      |
| Admin (mirror)        | `admin_demo/src/acl/*`, same client/hook pattern                                                  |

### Diagram: capabilities data path (high level)

```mermaid
flowchart LR
  Keys[AclPermissionKeys.cs]
  Me[MeController]
  Svc[AccessCapabilitiesService]
  FE[fe_demo src acl]
  AD[admin_demo src acl]
  Me --> Svc
  Keys -.-> Svc
  Svc -.-> FE
  Svc -.-> AD
```

**Full file-level flow:** see [acl-and-capabilities.md §3 Backend file map](../guides/acl-and-capabilities.md#3-backend-file-map) (canonical diagram scope).

## Full reference

→ [`../guides/acl-and-capabilities.md`](../guides/acl-and-capabilities.md) (keys, gates, tests, integration users).
