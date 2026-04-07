# Chat rooms: testy a prevádzka

Tento dokument popisuje **face chat rooms** (API, SignalR, FE routing), **automatické testy** a **manuálnu kontrolu** v prehliadači. Ad-hoc overenie HTTP (napr. curl) sa nerobí cez súbory v repozitári — len podľa potreby pri vývoji.

---

## 1. Backend (BeDemo.Api)

### 1.1 Spustenie v prostredí `Testing` (in-memory, bez Postgres)

Odporúčané pre **rýchlu manuálnu kontrolu** bez Dockeru (Swagger, Postman, jednorazový curl):

```bash
cd be_demo/BeDemo.Api
ASPNETCORE_ENVIRONMENT=Testing dotnet run --urls http://127.0.0.1:17778 --no-launch-profile
```

Pri štarte sa v `Program.cs` vykoná **`EnsureCreated` + `DatabaseSeeder.SeedDataOnlyAsync`**: role, face, stránky (rovnaké dáta ako pri integračných testoch). Bez tohto kroku by `dotnet run` s `Testing` mal **prázdnu DB** a registrácia by zlyhala na „USER role not found“.

**Poznámka:** Nepúšťajte súčasne `dotnet test` a `dotnet run` s `Testing` tak, aby oba zdieľali jednu in-memory inštanciu s rovnakým názvom databázy v **jednom procese** — integračné testy bežia v samostatnom procese, takže bežne nie je konflikt; problém bol skôr pri starom správaní bez seedu pri samostatnom `dotnet run`.

### 1.2 Produčný / dev režim (Postgres)

Použite `docker-compose.dev.yml` alebo vlastný connection string. Po migráciách sa volá plný `DatabaseSeeder.SeedAsync` + voliteľne `SeedUsersAsync`.

### 1.3 REST API (skrátený prehľad)

| Metóda | Cesta | Popis |
|--------|--------|--------|
| GET | `/api/faces/{faceId}/chat-rooms` | Zoznam miestností (host vidí `canParticipate: false`) |
| GET | `/api/faces/{faceId}/chat-rooms/{roomId}` | Detail |
| POST | `/api/faces/{faceId}/chat-rooms` | Používateľská miestnosť (`Face.ChatRoomsCreate`, nie host) |
| POST | `/api/faces/{faceId}/chat-rooms/system` | Systémová miestnosť (globálny admin) |
| POST | `/api/faces/{faceId}/chat-rooms/{roomId}/join` | Verejná miestnosť |
| POST | `/api/faces/{faceId}/chat-rooms/{roomId}/join-requests` | Súkromná miestnosť |
| POST | `/api/faces/{faceId}/chat-rooms/requests/{id}/approve` | Schválenie (iba tvorca) |
| POST | `/api/faces/{faceId}/chat-rooms/requests/{id}/deny` | Zamietnutie |
| GET | `/api/faces/{faceId}/chat-rooms/{roomId}/messages` | História (host alebo člen) |
| PUT/DELETE | `.../chat-rooms/{roomId}` | Úprava / zmazanie podľa pravidiel |

**OAuth2 (password grant)** (napr. pri ručnom volaní API):

- `POST /api/oauth2/register`
- `POST /api/oauth2/token` s `grantType=password`, `clientId=be-demo-client`, `clientSecret=be-demo-secret-very-strong-key`

**Úloha face role:** Nový používateľ má po registrácii **`FACE_HOST`**. Na vytvorenie miestnosti musí mať **`FACE_USER`** (alebo inú ne-host rolu): `PUT /api/faces/{faceId}/my-role` s `userRoleId` z `GET /api/faces/face-roles`.

**Zapnutie tvorby miestností:** `PUT /api/faces/{faceId}` s `{ "chatRoomsCreate": true }`.

### 1.4 SignalR

- Hub: **`/hubs/chatroom`**
- Metódy: `JoinRoom(faceChatRoomId)`, `LeaveRoom(faceChatRoomId)`, `SendRoomMessage(faceChatRoomId, content)`
- Klient: `ReceiveRoomMessage`, `ChatRoomClosed`
- Notifikácie o join request / idle close idú aj cez **`MessengerHub`** (`ReceiveNotification`) — pozri existujúci FE `MessengerContext`.

### 1.5 Idle lifecycle (Redis)

Job typ: `chatroom.idle-check`. Spracovanie v `RedisJobWorkerService` → `IChatRoomLifecycleService.ProcessIdleCheckAsync`. Ak bola aktivita pred menej ako 1 h, job sa znovu naplánuje; inak sa miestnosť zmaže a skupina dostane `ChatRoomClosed`.

---

## 2. Automatické testy — Backend (`BeDemo.Api.Tests`)

Spustenie:

```bash
cd be_demo
dotnet test BeDemo.Api.Tests/BeDemo.Api.Tests.csproj
```

### 2.1 `FaceChatRoomsControllerTests` (integrácia, WebApplicationFactory)

- **401** — list bez tokenu  
- **404** — neexistujúci `faceId`  
- **403** — `Create` pri vypnutom `ChatRoomsCreate`  
- **403** — `Create` pre **FACE_HOST**  
- **400** — prázdny názov miestnosti  
- **201** — vytvorenie, tvorca je členom  
- **404** — GET miestnosti pod iným `faceId`  
- **403** — join pre hosta  
- **200** — join verejnej miestnosti (FACE_USER)  
- **200** — duplicitný join → `alreadyMember`  
- **400** — join-request na verejnú miestnosť  
- **200** — join-request na súkromnú  
- **403** — správy pre nečlena (nie host)  
- **200** — správy pre hosta bez členstva  
- **403** — system create pre bežného používateľa  
- **201** — system create po **promócii používateľa na globálneho admina v DB** (test nemôže spoliehať na seed admin účty v in-memory)  
- **403** — delete cudzej miestnosti  
- **204** — delete vlastnej miestnosti  
- **200** — approve žiadosti tvorcom + overenie `isMember`  
- **200** — deny + overenie `!isMember`  
- **403** — approve cudzím používateľom  
- **Paginácia správ** — `beforeId` + vloženie správ cez `ApplicationDbContext`  

Pomocné metódy: `PromoteUserToGlobalAdminAsync` — nastaví `ApplicationUser.UserRoleId` na globálnu rolu **Admin** (API kontroluje DB, nie JWT).

### 2.2 `ChatRoomLifecycleServiceTests` (unit, InMemory + Moq)

- Žiadna miestnosť → žiadna výnimka, žiadny reschedule  
- Nedávna `LastMessageAt` → `IRedisJobQueue.ScheduleAsync("chatroom.idle-check", …)`  
- Stará aktivita, `CreatorUserId == null` → miestnosť zmazaná  
- `ScheduleIdleCheckAsync` → správny typ a payload  
- `LastMessageAt == null` → použije sa `CreatedAt` pre rozhodnutie o reschedule  

### 2.3 `FaceRoleParticipationTests`

- `IsHostFaceRole` len pre presný `FACE_HOST` (case sensitive)  
- `IsActiveForFaceRoleName` pre ne-host role  

---

## 3. Frontend (`fe_demo`)

```bash
cd fe_demo
yarn test
```

### 3.1 Nové / dotknuté súbory

- `src/api/services/__tests__/ChatRoomsService.test.ts` — URL, metódy, hlavičky, query `pageSize`/`beforeId`, chyba pri `!res.ok`  
- `src/constants/__tests__/componentTypeIds.test.ts` — chat varianty → **4**, stories/reels sanity  

### 3.2 Routing

- Detail: `/:lang/detail/4/:entityId` (`ComponentTypeId` chat = **4**)  
- Zoznam: `/:lang/list/4`  

---

## 4. Admin (`admin_demo`)

```bash
cd admin_demo
yarn test
```

- `useFacesApi`: typy `Face`, `CreateFaceData`, `UpdateFaceData` rozšírené o **`chatRoomsCreate`**  
- Test overí, že `updateFace` pošle `body.chatRoomsCreate`  

*(UI checkbox v edit forme môžete doplniť samostatne — API a typy sú pripravené.)*

---

## 5. Manuálny checklist (OAuth + UI)

1. Spustiť API (`Testing` alebo Postgres dev).  
2. Spustiť `fe_demo`, prihlásiť sa (rovnaký OAuth password flow ako v aplikácii).  
3. V nastaveniach face zvoliť **nie host** rolu, ak treba vytvárať miestnosti.  
4. Zapnúť **chat rooms create** na face (admin API alebo budúci admin UI).  
5. Otvoriť stránku s gridom chatu → klik na kartu → `/detail/4/{id}`.  
6. Overiť: host vidí históriu, nemôže písať; člen píše; SignalR doručuje správy.  
7. Notifikácie: súkromná miestnosť → join request → `ReceiveNotification` v messengri.  

---

## 6. Súhrn súborov (hlavné zmeny)

| Oblast | Súbor |
|--------|--------|
| BE seed Testing | `BeDemo.Api/Program.cs` |
| BE testy | `BeDemo.Api.Tests/FaceChatRoomsControllerTests.cs`, `ChatRoomLifecycleServiceTests.cs`, `FaceRoleParticipationTests.cs` |
| FE testy | `fe_demo/src/api/services/__tests__/ChatRoomsService.test.ts`, `fe_demo/src/constants/__tests__/componentTypeIds.test.ts` |
| Admin | `admin_demo/src/hooks/api/useFacesApi.ts`, `.../__tests__/useFacesApi.test.ts` |
| Dokumentácia | `docs/CHAT_ROOMS_TESTING_AND_OPERATIONS.md` |

---

## 7. Verifikácia v tomto repozitári (2026-04-07)

- `dotnet test BeDemo.Api.Tests` — **296 passed**, 1 skipped (existujúci).  
- `fe_demo` `yarn test` — **58 passed**.  
- `admin_demo` `yarn test` — **24 passed** (niektoré súbory skipped ako predtým).  

Pri problémoch skontrolujte URL API, prostredie (`Testing` vs Postgres) a OAuth `clientId` / `clientSecret` v `appsettings`.
