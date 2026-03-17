# MFAI Demo – Čo máme hotové (aktuálny stav)

Kompletný prehľad implementovaných častí projektu. Slúži ako podklad na dohodu, čo ďalej.

---

## 1. Koreň repozitára

### Štruktúra
- Monorepo: `be_demo`, `fe_demo`, `admin_demo`, `ai_demo`, `db_demo`, `logger_demo`.
- Hlavný `docker-compose.dev.yml` pre backend, frontend, admin, Seq, AI demo; DB a logger majú vlastné compose súbory.
- Bash skripty pre štart, stop, status, clear, rebuild, test, lint.

### Root skripty
| Skript | Účel |
|--------|------|
| **start-all-dev.sh** | Štart: DB → backend+Seq → frontend → AI demo → logger → admin; živý status každých 5 s; auto-restart zastavených kontajnerov. |
| **stop-all-dev.sh** | Zastavenie všetkých služieb v opačnom poradí. |
| **status-all.sh** | Jednorazový status: stav kontajnerov, HTTP/gRPC dostupnosť, porty, odkazy. |
| **clear-all-dev.sh** | Odstránenie kontajnerov a volumes (strata dát). |
| **restart-all-dev.sh** | Stop, rebuild obrázkov, start. |
| **rebuild-all-dev.sh** | Rebuild všetkých Docker obrázkov (bez štartu). |
| **test-all.sh** | Be_demo xUnit, fe_demo Vitest + Cypress e2e, admin_demo Vitest; súhrn pass/fail. |
| **lint-all.sh** | Spustí lint v fe_demo, be_demo, admin_demo, ai_demo. |
| **menu.sh** | TUI menu v štýle Norton Commander: šípky, Enter = vstup/spustenie, Backspace/←/Esc = späť; root skripty + skripty po kontajneroch (be_demo, fe_demo, …). |

### Konfigurácia
- **docker-compose.dev.yml**: služby `be-demo-dev` (8000/8001), `fe-demo-dev` (8081), `admin-demo-dev` (8082), `seq` (5341), `ai-demo-dev` (50051); sieť `dev-network`; env pre API URL, Seq, DB; healthchecks; volumes (node_modules, yarn cache, HTTPS cert, seq-data, HuggingFace cache).
- **README.md**: prehľad, štruktúra, quick start, porty, default credentials, zoznam skriptov, troubleshooting.

---

## 2. Backend (be_demo)

### Technológie
- ASP.NET Core 10, Identity, EF Core 10, Npgsql (PostgreSQL), JWT Bearer, Serilog + Seq, Swagger, SignalR, gRPC klient (AI).

### Kontroléry
| Kontrolér | Funkcie |
|-----------|---------|
| **AuthController** | Register, login, logout. |
| **OAuth2Controller** | Token, register (OAuth2Service). |
| **UsersController** | CRUD používateľov; **GetUsers** s pagináciou a search (`page`, `pageSize`, `search`, `forAddFriend`); pri `forAddFriend=true` vracia len používateľov, ktorých môže aktuálny user pridať (bez seba, priateľov a pending friend requestov). |
| **FacesController** | CRUD faces; **GET config** vracia pri auth aj **myFaceRoleId**, **myFaceRoleName** pre každý face; **GET face-roles** (zoznam face rolí); **PUT {id}/my-role** (nastavenie vlastnej face role). |
| **PagesController** | CRUD stránok. |
| **PageTypesController** | CRUD typov stránok. |
| **FriendRequestsController** | Žiadosti o priateľstvo: zoznam, odoslanie, prijatie, odmietnutie. |

### SignalR Huby
| Hub | Endpoint | Funkcie |
|-----|----------|---------|
| **ChatHub** | `/hubs/chat` | SendMessage (broadcast), SendPrivateMessage, **SendToAi** (gRPC volanie AI služby, history, ReceiveAiMessage); 401 pri neplatnom tokene. |
| **MessengerHub** | `/hubs/messenger` | SendChatMessage(receiverId, content), AcceptMessageRequest(senderId), RejectMessageRequest(senderId); callbacks: ReceiveChatMessage, ReceiveMessageRequest, ReceiveFriendRequest, MessageRequestAccepted, MessageRequestRejected, ReceiveNotification. |

### Služby
- **OAuth2Service**, **ECDSAKeyService** (JWT podpis).
- **FaceService** – lookup face podľa indexu (kebab-case), cache.
- **UserService** – používatelia.
- **AiGrpcService** – gRPC klient k ai_demo (Health, Generate); keepalive 60s/30s; handling MODEL_LOADING a chýb.

### Middleware
- **RoutingMiddleware** – face prefix z URL, rewrite na `/api/{face-id}/...?requestFaceID=...`; public paths obídené; 403 pri neplatnom face.
- **OAuth2Middleware** – validácia OAuth2 tokenov.

### Dáta (EF Core)
- **Identity**: ApplicationUser, UserRole (s **Scope**: Global/Face).
- **FriendRequest**, **Friendship**, **Message** (IsMessageRequest, MessageRequestStatus), **Notification**.
- **Face**, **Page**, **PageType**, **PageRouteTranslation**.
- **UserProfile**, **UserFaceProfile**, **UserFaceRole** (rola používateľa v rámci face).

#### Roly (globálne a face)
- **Globálne roly** (jedna na používateľa, `ApplicationUser.UserRoleId`): **SUPER_ADMIN**, **ADMIN**, **USER**, **HOST**.
- **Face roly** (per user per face, tabuľka **UserFaceRole**): **FACE_ADMIN**, **FACE_USER**, **INZERENT**, **SUBSCRIBER**, **FACE_HOST**.
- **UserRole** má pole **Scope** (enum: Global, Face); konštanty v `UserRole.GlobalRoleNames` a `UserRole.FaceRoleNames`.
- Pri **registrácii** sa používateľovi nastaví globálna rola **USER**.
- Pri vytvorení väzby na face (UserFaceProfile) sa automaticky pridá **UserFaceRole** s rolou **FACE_HOST** pre daný face.
- Seed: globálne a face roly so Scope; pri seede používateľov sa pre každý face vytvorí UserFaceRole FACE_HOST.

#### Default stránky pri vytvorení face
- Pri **POST /api/faces** (vytvorení nového face) sa automaticky vytvoria stránky podľa existujúcich PageTypes: **Home** (`/home`), **List** (`/list`), **Detail** (`/detail`).
- Ak je face **nepublic** (`IsPublic = false`), pridá sa navyše stránka **Wall** (`/wall`) – PageType `"wall"`.
- PageType `"wall"` je v seede PageTypes; v seede faces majú neverejné faces (basic, koncept) v zozname pages aj Wall.

#### Výber face role pri prvom visite (súkromný face)
- **GET /api/faces/config**: pri požiadavke s Authorization header sa pre každý face doplní **myFaceRoleId** a **myFaceRoleName** (aktuálna rola používateľa v tom face).
- **GET /api/faces/face-roles** (AllowAnonymous): vracia zoznam face rolí `[{ id, name }]` pre dropdown vo frontende.
- **PUT /api/faces/{id}/my-role** (Authorize): body `{ userRoleId }` – nastaví alebo vytvorí **UserFaceRole** pre aktuálneho používateľa a daný face; validuje, že rola má Scope = Face.

### Ďalšie
- Swagger/OpenAPI, health checks, AI gRPC health pri štarte.
- ChatHub SendToAi: try/catch, user-friendly chybová hláška pri nedostupnosti AI.

---

## 3. Frontend (fe_demo)

### Technológie
- React 18, TypeScript, Vite, React Router, TanStack Query, Bootstrap, Radix UI, react-i18next, axios, react-toastify, @microsoft/signalr, OpenAPI klient.

### Autentifikácia a session
- Registrácia, login, protected/guest routes.
- **AuthContext**: JWT v localStorage, session watcher (kontrola expirácie každých 30 s), kontrola pri načítaní, **401 interceptor** – pri expirovanom/neplatnom tokene automatické odhlásenie.
- Logout v Headeri (prvá položka v nav).

### Lokalizácia a routing
- i18n: en/sk/cz; lokalizované cesty (napr. `/en/login`, `/sk/prihlasenie`).
- **Face-based routing**: prefix z URL (napr. `/acme-corp/dashboard`); API klient pridáva face path do requestov; FaceConfigProvider, dynamické stránky z backendu (public/private faces).

### UI komponenty a stránky
- **Header**, **Footer** (Messenger link), **LanguageSwitcher**, **ProtectedRoute**, **GuestRoute**, **FacePageView**.
- **Horný panel pri prvom visite súkromného face**: **FaceRoleSelectPanel** – zobrazí sa pod Headerom, keď je používateľ prihlásený, má zvolený súkromný face a v `localStorage` ešte nie je kľúč `face_role_chosen_{faceId}`. Panel obsahuje dropdown s face rolami (z API GET face-roles) a tlačidlo Potvrdiť; po uložení (PUT my-role) sa nastaví localStorage a config sa znovu načíta, panel sa ďalej nezobrazuje.
- **Settings panel**: jazyk, logout, výber face, Pages nav, **Friend Requests**, **Messenger**, **Notifications** (tabs).
- Stránky: Home (guest), Login, Register, HomePageProtected, Profile, **Users** (zoznam + detail), dynamické face stránky.

### Friend Requests (Add Friend)
- **FriendRequestsTab**: prichádzajúce žiadosti (accept/reject), sekcia „Add friend“.
- **Backend paginácia a search**: `getUsers(token, { page, pageSize, search, forAddFriend: true })`; odpoveď `{ items, totalCount, page, pageSize, totalPages }`.
- **Dynamický pageSize**: výpočet podľa dostupnej výšky (ResizeObserver, ITEM_HEIGHT_PX, PAGINATION_HEIGHT_PX, SAFETY_MARGIN_PX); žiadny scroll v liste – presne toľko položiek, koľko sa zmestí; paginácia Next/Prev.
- Debounce search 300 ms; oddelené loading stavy pre requests vs addable users; optimistické odstránenie po odoslaní žiadosti (sentToIds).
- Layout: flex, sekcia Add friend s `friend-requests-list-wrapper` (overflow: hidden), aby obsah nepretekal pod footer.

### Messenger
- **MessengerContext**: SignalR pripojenie na `/hubs/messenger`, stavy Connecting/Connected/Disconnected.
- **MessengerTab**: zoznam konverzácií, message requests (accept/reject), chat s vybraným používateľom; odoslanie správy, prijímanie v reálnom čase (ReceiveChatMessage, ReceiveMessageRequest, …).
- Formátovanie času (dnes čas, inak dátum+čas), connection status v UI.

### Notifications
- **NotificationsTab**: zobrazenie notifikácií (napr. message request).

### API a konfigurácia
- **getFacesConfig(token?)**: pri zadanom tokene posiela Authorization header; backend vráti pre každý face aj **myFaceRoleId**, **myFaceRoleName**. FaceConfigProvider volá load s tokenom, keď je používateľ prihlásený.
- **FaceRolesService**: **getFaceRoles()** – GET /api/faces/face-roles; **setMyFaceRole(faceId, userRoleId, token)** – PUT /api/faces/{id}/my-role.
- **UsersListService**: getUsers s parametrami (page, pageSize, search, forAddFriend), GetUsersResponse; getUser(id).
- **authAwareFetch**: 401 handling, odhlásenie.
- **env**: VITE_API_URL, VITE_API_HTTPS_URL, OAuth2, Seq proxy, app name/version.
- Vite proxy pre API a (voliteľne) Seq; v dev móde môže byť Seq logging vypnutý.

### Testovanie
- Vitest, Cypress e2e; lint, format, type-check, generate:api.

---

## 4. Admin panel (admin_demo)

### Technológie
- React 18, TypeScript, Vite, React Router, TanStack Query, Bootstrap, Radix UI, axios, react-toastify, @microsoft/signalr, OpenAPI klient.

### Funkcie
- OAuth2 login, chránené admin routes.
- **CRUD**: Users (zoznam, detail, create, edit), Faces (zoznam, detail, create, edit), Pages (zoznam, detail, create, edit), Page Types.
- **AdminLayout**: sidebar + header, tabuľky (sort, pagination), formuláre, toasty.
- i18n en/sk/cz, lokalizované cesty.
- Stránky: Dashboard, Login, Users, Faces, Pages, Chat (ak je).

### Konfigurácia
- Port 8082; env VITE_API_URL, VITE_PORT; Docker v root compose.

---

## 5. AI služba (ai_demo)

### Technológie
- Python 3.11, gRPC (grpcio, grpcio-tools, protobuf), transformers, torch, accelerate (DistilGPT-2).

### Funkcie
- **HealthCheck** RPC; backend ho volá pri štarte.
- **Generate** RPC (prompt, max_new_tokens); model DistilGPT-2 (Hugging Face, lokálne).
- **Exception handling**: RuntimeError s „MODEL_LOADING“ – vracia priateľskú hlášku (model sa načítava); ostatné chyby logované a vrátené v response.
- **gRPC server options**: keepalive (permit without calls, min ping interval), aby .NET klient mohol posielať pingy počas dlhého čakania na Generate.

### Konfigurácia
- Port 50051; proto health.proto; generate_proto.sh; Docker s HF_HOME volume, memory limit, dlhý start_period.

---

## 6. Databáza (db_demo)

- PostgreSQL 16 (postgres:16-alpine), pgAdmin 4.
- Porty: 54320 (PostgreSQL), 5050 (pgAdmin).
- DB: bedemo, user bedemo_user; volume pre perzistenciu; healthcheck.
- **servers.json** pre pgAdmin (BeDemo Database, host postgres-dev).
- Migrácie cez backend (EF Core).

---

## 7. Logger (logger_demo)

- Dozzle – real-time logy všetkých kontajnerov.
- Port 8080; discovery z Docker socketu; filter podľa kontajnera.

---

## 8. Súhrn – čo je hotové

| Oblasť | Stav |
|--------|------|
| **Auth** | Backend: OAuth2 + JWT, Identity, ECDSA. FE/Admin: login, register, protected/guest routes, token v API kliente, **auto-logout pri 401/expire**, logout v menu. |
| **API** | REST (Swagger), face-prefixed routes; FE/Admin klient z OpenAPI. |
| **Používatelia** | GetUsers s **pagináciou a search**, **forAddFriend** pre Add Friend; UsersPage, UserDetailPage. |
| **Friend Requests** | Backend: FriendRequestsController; FE: FriendRequestsTab, **backend paginácia + search**, **dynamický počet položiek podľa výšky**, debounce, optimistické UI. |
| **Real-time** | SignalR: **ChatHub** (broadcast, private, **SendToAi**), **MessengerHub** (chat, message requests, notifikácie); FE MessengerContext, MessengerTab, NotificationsTab. |
| **AI** | ai_demo gRPC Health + Generate (DistilGPT-2); backend AiGrpcService; ChatHub SendToAi + history; error handling a keepalive. |
| **Databáza** | PostgreSQL 16, EF Core migrácie, Identity + FriendRequest, Friendship, Message, Notification, Face, Page, … |
| **Multi-tenant** | Face-based routing (backend middleware + FE face path); public/private faces. |
| **DevOps** | Docker Compose, skripty start/stop/status/clear/rebuild/test/lint, **menu.sh** (NC-štýl TUI). |
| **Logging** | Serilog → Seq (backend); Dozzle (všetky kontajnerov). |

---

## 9. Čo ďalej (na dohodu)

- Rozšírenie funkcionalít (nové moduly, reporty, …).
- Testy: pokrytie, ďalšie e2e scenáre.
- UX/UI: úpravy Friend Requests / Messenger / Notifications.
- Bezpečnosť a výkon: rate limiting, caching, hardening.
- Dokumentácia: API, deployment, runbook.
- Iné priority podľa potreby projektu.

---

*Dokument popisuje stav projektu k dátumu poslednej úpravy. Ďalší postup sa dohodne na základe tohto prehľadu.*
