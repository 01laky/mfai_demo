# SignalR hub security matrix (`be_demo`)

Language: English. **Automation:** where an automated test exists, it is referenced; otherwise manual verification steps are listed (security-hardening prompt, hub inventory).

## Hub inventory

| Hub file                     | `[Authorize]` | JWT source                                                                                                       | Face / tenant                                                               | Automated coverage                                                                                  |
| ---------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `BeDemo.Api/Hubs/ChatHub.cs` | Yes           | Same as HTTP: `access_token` query on `/hubs/chat` (see `Program.cs` `OnMessageReceived`); **J6** `atv` enforced | URL is face-prefixed when clients use `/{face}/hubs/...` (see routing docs) | `SignalRHubTests`, `SignalREdgeCaseTests` (partial); no-token / wrong-face cases — extend as needed |

## Manual checks (repeat per release if tests not extended)

1. **No token:** connect to `wss://host/{face}/hubs/chat?access_token=` empty → connection must fail / close unauthorized.
2. **Wrong face:** valid JWT for user without access to `{face}` → hub must reject sensitive operations per `IAccessEvaluator` / face scope rules.
3. **Short-lived token:** connect with valid token, wait past `exp`, invoke hub method → expect unauthorized / disconnect per server configuration.

## Related

- [security-crypto-sockets.md](./security-crypto-sockets.md) — S1–S6 backlog vs implementation.
- [acl-and-capabilities.md](./acl-and-capabilities.md) — authorization model for hub methods.
