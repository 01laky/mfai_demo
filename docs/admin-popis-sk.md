# Admin panel – Funkčný popis

## Prehľad

Admin panel je administračné rozhranie pre správu celej platformy. Administrátor tu spravuje používateľov, faces (prostredia), stránky a ich obsah. Panel obsahuje aj AI Chat asistenta.

Aplikácia je dostupná na adrese **http://localhost:8082**.

---

## 1. Prihlásenie

Admin vidí jednoduchý prihlasovací formulár:
- **Email** (povinný, validný formát)
- **Heslo** (min. 4 znaky)
- Tlačidlo **Prihlásiť sa**

Po úspešnom prihlásení sa admin presunie na Nástenku. Pri neúspechu sa zobrazí chybová hláška.

Ak sa neprihlásený admin pokúsi otvoriť chránenú stránku, je presmerovaný na prihlásenie a po prihlásení sa vráti na pôvodnú stránku.

---

## 2. Rozloženie a navigácia

Po prihlásení sa zobrazí hlavné rozhranie:

### Horná lišta (Header)

- **Hamburger menu** – otvára/zatvára sidebar na mobile.
- **Názov**: Admin Demo.
- **Prepínač jazyka** (SK / EN / CZ).
- **Email admina** + tlačidlo **Odhlásiť**.

### Ľavý sidebar

Hlavné navigačné položky:
- **Nástenka** – prehľadové štatistiky.
- **Používatelia** – správa používateľov.
- **Tváre** – správa faces.
- **AI Chat** – chat s AI asistentom.

Na mobilných zariadeniach sa sidebar otvára ako prekryvný panel.

---

## 3. Jazyky

Admin panel podporuje 3 jazyky:
- **Slovenčina** (sk)
- **Angličtina** (en)
- **Čeština** (cz)

Prepínanie v hornej lište. URL sa automaticky preloží (napr. `/sk/nastenka` ↔ `/en/dashboard`).

---

## 4. Nástenka (Dashboard)

Po prihlásení admin vidí:

### Privítanie
Text s emailom prihláseného admina.

### Prehľadové karty

| Karta | Čo zobrazuje |
|-------|--------------|
| **Používatelia** | Celkový počet používateľov |
| **Tváre** | Počet faces |
| **Žiadosti o priateľstvo** | Počet žiadostí |
| **Správy** | Počet správ |

### Rýchle akcie

- **Správa používateľov** – odkaz na zoznam používateľov.
- **Správa tvárí** – odkaz na zoznam faces.

Každá karta je klikateľná a vedie do príslušného modulu.

---

## 5. Správa používateľov

### Zoznam používateľov

- **Vyhľadávanie** – filtrovanie podľa textu.
- **Obnoviť** – obnovenie zoznamu.
- **Vytvoriť používateľa** – tlačidlo na vytvorenie nového.
- **Tabuľka** s triedením a stránkovaním.

Stĺpce tabuľky:

| Stĺpec | Popis |
|---------|-------|
| **ID** | Klikateľné – otvorí detail |
| **Email** | Emailová adresa |
| **Meno** | Krstné meno |
| **Priezvisko** | Priezvisko |
| **Vytvorené** | Dátum vytvorenia |
| **Akcie** | Tlačidlo Upraviť |

### Detail používateľa

Zobrazuje: ID, Email, Meno, Priezvisko, Dátum vytvorenia.

### Vytvorenie používateľa

Formulár s poliami:
- **Email** (povinný)
- **Meno** (povinné)
- **Priezvisko** (povinné)
- **Heslo** (povinné)
- **Potvrdenie hesla** (povinné)

Po úspešnom vytvorení návrat na zoznam.

### Úprava používateľa

Formulár s poliami:
- **Email**
- **Meno**
- **Priezvisko**
- **Heslo** (voliteľné – ak zostane prázdne, heslo sa nemení)
- **Potvrdenie hesla** (voliteľné)

> **Poznámka**: Mazanie používateľov nie je v admin paneli dostupné.

---

## 6. Správa tvárí (Faces)

Face je „prostredie" alebo „priestor" v rámci frontendovej aplikácie – každá face má vlastné stránky, obsah a nastavenia.

### Zoznam tvárí

- **Vyhľadávanie**, **Obnoviť**, **Vytvoriť tvár**.
- Tabuľka s triedením a stránkovaním.

Stĺpce tabuľky:

| Stĺpec | Popis |
|---------|-------|
| **ID** | Klikateľné – otvorí detail |
| **Index** | Technický identifikátor (napr. `acme-corp`) |
| **Názov** | Zobrazovaný názov |
| **Popis** | Skrátený popis |
| **Farba** | Farebný badge |
| **Viditeľnosť** | Verejná / Súkromná (badge) |
| **Akcie** | Tlačidlo Upraviť |

### Detail tváre

Zobrazuje:
- ID, Index, Názov, Viditeľnosť (Verejná/Súkromná), Popis, Farba, dátumy vytvorenia a aktualizácie.
- **Sekcia Stránky tváre** – vnorený zoznam všetkých stránok patriacich tejto face.

### Vytvorenie tváre

Formulár s poliami:
- **Index** – unikátny identifikátor v URL (napr. `nova-face`)
- **Názov** – zobrazovaný názov
- **Popis** – popis face
- **Farba** – farba face
- **Verejný prístup** – prepínač, či je face verejná alebo súkromná

Pri vytvorení sa automaticky vytvoria predvolené stránky (Home, List, Detail; pri súkromnej face aj Wall).

### Úprava tváre

Obsahuje rovnaké polia ako vytvorenie, plus:

#### Nastavenia gradientu pozadia

Pokročilý editor vizuálu face:
- **Typ gradientu** – lineárny / radiálny
- **Uhol** – smer gradientu (0°–360°)
- **Farby** – zoznam farieb s pozíciami (možnosť pridať/odobrať)
- **Animácia** – zapnutie/vypnutie animácie gradientu
- **Rýchlosť** – rýchlosť animácie (v sekundách)

#### Správa stránok

V rámci editácie face sa zobrazuje aj tabuľka stránok s možnosťou vytvoriť novú stránku.

> **Poznámka**: Mazanie faces nie je v admin paneli dostupné.

---

## 7. Správa stránok

Stránky sú vždy viazané na konkrétnu face. Správa stránok sa spúšťa z detailu alebo editácie face.

### Vytvorenie stránky

Formulár s poliami:
- **Typ stránky** – výber z existujúcich typov (Home, List, Detail, Wall)
- **Názov** – názov stránky
- **Cesta** – URL cesta (napr. `/domov`)
- **Index** – poradové číslo
- **Popis** – popis stránky

#### Preklady trás

Sekcia pre nastavenie preložených URL segmentov:
- **Angličtina** (en) – napr. `home`
- **Slovenčina** (sk) – napr. `domov`
- **Čeština** (cz) – napr. `domu`

Tieto preklady sa používajú v URL podľa zvoleného jazyka na frontende.

### Detail stránky

Zobrazuje: ID, Názov, Cesta, Index, Popis, dátumy.

### Úprava stránky

Rovnaké polia ako pri vytvorení + úprava prekladov trás.

#### Vizuálny editor rozloženia (Grid Layout Editor)

Kľúčová funkcia admin panelu – blokový editor rozloženia stránky:

- **Pridať blok** – pridá nový prázdny blok do mriežky.
- **Presúvanie blokov** – drag & drop.
- **Zmena veľkosti** – ťahaním za okraj bloku.
- **Premenovanie** – dvojklik na blok.
- **Vymazanie** – tlačidlo na vymazanie bloku.
- **Priradenie komponentu** – kliknutím do bloku sa otvorí modálne okno s výberom typu obsahu.

#### Typy komponentov

Modálne okno ponúka kategórie:

| Kategória | Popis |
|-----------|-------|
| **Albumy** | Fotky a albumy (single / grid / carousel) |
| **Inzercia** | Inzeráty s cenou a lokalitou (single / grid / carousel) |
| **Blog** | Články s dátumom a titulkom (single / grid / carousel) |
| **Chat miestnosti** | Chatové miestnosti (single / grid / carousel) |
| **Profily** | Profily používateľov (single / grid / carousel) |
| **Reels** | Krátke video karty (single / grid / carousel) |
| **Stories** | Story bubliny (single / grid / carousel) |

Každá kategória má tri varianty zobrazenia: **single** (jedna karta), **grid** (mriežka), **carousel** (horizontálny posuv).

### Vymazanie stránky

V tabuľke stránok je pri každej stránke tlačidlo **Vymazať** s potvrdzovacím dialógom.

---

## 8. AI Chat

Dostupný z bočného menu pod položkou **AI Chat**.

### Funkcie

- **Stav pripojenia**: Pripájanie / Pripojený / Odpojený.
- **História správ** – zobrazená ako konverzácia medzi „Vy" a „AI".
- **Vstupné pole** + tlačidlo **Odoslať**.
- Počas generovania odpovede sa zobrazuje indikátor „AI píše...".
- Pri dlhšom spracovaní sa zobrazí informácia o čakaní.
- História správ zostáva v rámci relácie prehliadača (po obnovení stránky sa vymaže).

---

## 9. Typický pracovný postup admina

1. **Prihlásenie** – admin sa prihlási emailom a heslom.
2. **Nástenka** – skontroluje prehľadové štatistiky.
3. **Správa používateľov** – podľa potreby vytvára alebo upravuje používateľov.
4. **Správa tvárí** – vytvára nové faces, nastavuje ich vizuál (gradient), viditeľnosť.
5. **Správa stránok** – v rámci face vytvára stránky, nastavuje URL preklady a zostavuje rozloženie cez vizuálny editor.
6. **AI Chat** – kedykoľvek môže využiť AI asistenta.

---

## 10. Albumy (API)

Backend poskytuje plnohodnotný REST API pre správu albumov. Album je entita vytvorená používateľom s väzbami na faces, komentáre a lajky.

### Dátový model

- **Album** – `title`, `description`, `albumType` (Public/Private/Paid), `mediaType` (Image/Video), `creatorId`
- **AlbumFace** – väzba album ↔ face (many-to-many)
- **AlbumComment** – komentáre k albumom (`content`, `userId`, `albumId`)
- **AlbumLike** – unikátny lajk per user per album

### API endpointy

**Albumy:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/albums` | Všetky viditeľné albumy |
| `GET` | `/api/albums/{id}` | Detail albumu |
| `GET` | `/api/albums/user/{userId}` | Albumy používateľa |
| `POST` | `/api/albums` | Vytvoriť album |
| `PUT` | `/api/albums/{id}` | Upraviť album (len creator) |
| `DELETE` | `/api/albums/{id}` | Zmazať album (len creator) |

**Komentáre:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/albums/{id}/comments` | Komentáre albumu |
| `POST` | `/api/albums/{id}/comments` | Pridať komentár |
| `PUT` | `/api/albums/{id}/comments/{cid}` | Upraviť komentár |
| `DELETE` | `/api/albums/{id}/comments/{cid}` | Zmazať komentár |

**Lajky:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/albums/{id}/likes` | Zoznam lajkov |
| `POST` | `/api/albums/{id}/likes` | Lajknúť album |
| `DELETE` | `/api/albums/{id}/likes` | Odlajknúť album |

### Viditeľnosť

- **Public** – vidí každý prihlásený používateľ
- **Private** – vidí len tvorca
- **Paid** – zatiaľ len tvorca (pripravené na budúci paywall)

---

## 11. Reels (API) a Redis fronta

### Reels – dátový model

- **Reel** – `title`, `description`, `videoUrl`, `creatorId`
- **ReelFace** – väzba reel ↔ face; **žiadny záznam** = reel je globálny pre všetky faces, inak len na uvedených faces
- **ReelComment**, **ReelLike** – rovnaký vzor ako pri albumoch

### Reels – API (skrátené)

| Metóda | Endpoint | Poznámka |
|--------|----------|----------|
| `GET` | `/api/reels?faceId=` | Voliteľný filter podľa face |
| `GET` | `/api/reels/{id}?faceId=` | Pre scoped reels treba správny `faceId` |
| `POST` / `PUT` / `DELETE` | `/api/reels` … | CRUD ako albumy |
| Komentáre / lajky | `/api/reels/{id}/comments`, `/likes` | Query `faceId` kde treba |

Po **POST** `/api/reels` sa do Redis zaradí okamžitá úloha `reel.postprocess` a odložená úloha (~1 min) – na rozšírenie o transcoding / notifikácie.

### Redis (submodule `redis_demo`)

Ako **`db_demo`**: samostatný submodule s vlastným `docker-compose.yml`. `be-demo-dev` má **`Redis__Configuration=host.docker.internal:6379`** a `extra_hosts` pre Linux. Kľúče: `bedemo:jobs:ready`, `bedemo:jobs:delayed`. Bez Redis / prázdna konfigurácia / **Testing** → NoOp. [`redis-subrepo-dev-sk.md`](./redis-subrepo-dev-sk.md), `redis_demo/README.md`.

---

## 12. Blog (API)

Backend poskytuje plné CRUD API pre blogové príspevky vrátane komentárov a lajkov.

### Dátový model

- **Blog** – Id, CreatorId, FaceId (povinný FK na Face), Title, Content (text/HTML), CreatedAt, UpdatedAt
- **BlogImage** – Id, BlogId, ImageUrl, SortOrder (max 3 per blog)
- **BlogComment** – Id, BlogId, UserId, Content, CreatedAt, UpdatedAt
- **BlogLike** – Id, BlogId, UserId, CreatedAt (unikátny pár BlogId+UserId)

### API endpointy

**Blogy:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/blogs?faceId={faceId}` | Zoznam blogov (voliteľný filter podľa face) |
| `GET` | `/api/blogs/{id}` | Detail blogu |
| `POST` | `/api/blogs` | Vytvoriť blog (title, content, faceId, imageUrls?) |
| `PUT` | `/api/blogs/{id}` | Upraviť blog (len creator) |
| `DELETE` | `/api/blogs/{id}` | Zmazať blog (len creator) |

**Komentáre:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/blogs/{id}/comments` | Komentáre blogu |
| `POST` | `/api/blogs/{id}/comments` | Pridať komentár |
| `PUT` | `/api/blogs/{id}/comments/{cid}` | Upraviť komentár (len autor) |
| `DELETE` | `/api/blogs/{id}/comments/{cid}` | Zmazať komentár (len autor) |

**Lajky:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/blogs/{id}/likes` | Zoznam lajkov |
| `POST` | `/api/blogs/{id}/likes` | Lajknúť blog |
| `DELETE` | `/api/blogs/{id}/likes` | Odlajknúť blog |

### Kľúčové vlastnosti

- Blog je povinne priradený k jednej Face (single select, nie multiselect)
- Obsah je ukladaný ako HTML (z WYSIWYG editora)
- Maximum 3 obrázkov per blog (vynútené na úrovni controllera)
- Komentáre a lajky môže pridávať každý prihlásený používateľ
- Upravovať/mazať blog môže len jeho tvorca
- Lajk je unikátny per blog per používateľ

---

## 13. Predvolené prihlasovacie údaje

- **Email**: `admin@admin.com`
- **Heslo**: `admin`
