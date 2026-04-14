# Monorepo dependency audit — completion record

**Snapshot date:** 2026-04-10  
**Canonical prompt:** [docs/prompts/monorepo-dependency-audit-and-upgrade-agent-prompt.md](../prompts/monorepo-dependency-audit-and-upgrade-agent-prompt.md) (§0, §2.1–2.3 refreshed in-tree).

## Evidence (commands)

From monorepo root unless noted.

### Node — `npm-check-updates` (no manifest changes)

- `fe_demo`: `npx --yes npm-check-updates` → *All dependencies match the latest package versions.*
- `admin_demo`: same.

### Node — §2.3 union table

- Regenerated via `npm view <pkg> version` for the union of `fe_demo` and `admin_demo` direct dependencies (see §0.1 script in the prompt). Output is pasted under **§2.3** in the prompt file.

### .NET — outdated top-level packages

```text
cd be_demo && dotnet list package --outdated
```

Result at snapshot: only **Google.Protobuf**, **Grpc.Net.Client**, **Grpc.Tools** show newer **Latest** lines vs **Resolved**. The audit prompt keeps these on a **hold** until gRPC/protobuf bumps are validated (arm64 / Docker `protoc`).

## Follow-up (not done in this pass)

- Bump gRPC triplet with full `dotnet test` + any stub regeneration checks.
- Optional: Docker image pin review per prompt §4.

### SPA `yarn npm audit` (informational re-check)

- **2026-04-11:** From `fe_demo/` and `admin_demo/`, `yarn npm audit` reported **no audit suggestions** (Yarn 4 / registry advisory database at run time).

