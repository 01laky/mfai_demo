# SignalR hub security matrix (`many_faces_backend`)

Language: English. **Automation:** where an automated test exists, it is referenced; otherwise manual verification steps are listed (security-hardening prompt, hub inventory).

## Hub inventory

| Hub file                         | `[Authorize]` | JWT source                                                                                                       | Face / tenant                                                               | Automated coverage                                                                                  |
| -------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `BeDemo.Api/Hubs/ChatHub.cs`     | Yes           | Same as HTTP: `access_token` query on `/hubs/chat` (see `Program.cs` `OnMessageReceived`); **J6** `atv` enforced | URL is face-prefixed when clients use `/{face}/hubs/...` (see routing docs) | `SignalRHubTests` — no-token failure + **`ChatHub_ShouldConnect_WhenValidJwtInQueryString`** (long-polling) |
| `BeDemo.Api/Hubs/MessengerHub.cs` | Yes          | Same JWT rules as `ChatHub` on `/hubs/messenger`                                                                 | `IFaceScopeContext` + `EnforceTenantSocialPairAsync` for DM paths           | `SignalRHubTests.MessengerHub_ShouldRejectConnection_WhenNoToken`                                    |
| `BeDemo.Api/Hubs/ChatRoomHub.cs` | Yes          | Same on `/hubs/chatroom`                                                                                         | `JoinRoom` validates room membership + face                                 | `SignalRHubTests.ChatRoomHub_ShouldRejectConnection_WhenNoToken`                                    |

Full engagement evidence: [security-crypto-sockets.md — completion record](./security-crypto-sockets.md#security-hardening-engagement--completion-record-2026-04-11).

## Manual checks (repeat per release if tests not extended)

1. **No token:** connect to `wss://host/{face}/hubs/chat?access_token=` empty → connection must fail / close unauthorized.
2. **Wrong face:** valid JWT for user without access to `{face}` → hub must reject sensitive operations per `IAccessEvaluator` / face scope rules.
3. **Short-lived token:** connect with valid token, wait past `exp`, invoke hub method → expect unauthorized / disconnect per server configuration.

## Related

- [security-crypto-sockets.md](./security-crypto-sockets.md) — S1–S6 backlog vs implementation.
- [acl-and-capabilities.md](./acl-and-capabilities.md) — authorization model for hub methods.
