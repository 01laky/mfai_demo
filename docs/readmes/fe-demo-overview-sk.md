# Frontend aplikácia – Funkčný popis

## Prehľad

Frontend je používateľská aplikácia typu sociálna sieť s multi-face architektúrou. Používateľ sa pohybuje v rámci zvolenej **face** (prostredia), kde vidí dynamické stránky s obsahom, messenger, notifikácie, priateľov a svoj profil.

Aplikácia je dostupná na adrese **http://localhost:8081**.

---

## 1. Prihlásenie a registrácia

### Registrácia

Nový používateľ vyplní formulár:
- **Email** (povinný, validný formát)
- **Heslo** (min. 4 znaky, musí obsahovať malé písmeno, veľké písmeno a číslo)
- **Meno**
- **Priezvisko**

Po úspešnej registrácii sa zobrazí oznámenie a používateľ je presmerovaný na prihlásenie.

### Prihlásenie

Prihlasovací formulár obsahuje:
- **Email** (povinný)
- **Heslo** (min. 4 znaky)
- **Zaškrtávacie pole „Zostať trvalo prihlásený“** — ak je zaškrtnuté, API vydá JWT s **dlhšou platnosťou** (konfigurácia `Jwt:ExpiresInMinutesRememberMe`); ak nie, platí kratšia relácia (`Jwt:ExpiresInMinutes`). Ide o rovnaký typ tokenu v `localStorage`, líši sa len čas v nároku `exp`. Technický rozbor: [**authentication-and-sessions-sk.md**](./authentication-and-sessions-sk.md).

Po úspešnom prihlásení sa používateľ dostane na domovskú stránku aktuálnej face.

### Automatické odhlásenie

Ak **vyprší platnosť JWT** (nárok `exp`), aplikácia vyčistí uložený token a používateľ uvidí hlášku o vypršanej relácii; API už nebude requesty s týmto tokenom akceptovať. Periódická kontrola beží aj na pozadí (cca každých 30 s). Viac v [**authentication-and-sessions-sk.md**](./authentication-and-sessions-sk.md).

---

## 2. Čo je Face

**Face** je samostatné prostredie v rámci aplikácie – niečo ako „priestor" alebo „komunita" s vlastnými stránkami a obsahom.

- **Verejná face** – viditeľná pre všetkých, aj neprihlásených používateľov.
- **Súkromná face** – prístupná len po prihlásení.

Používateľ vždy pracuje v jednej vybranej face. URL adresa obsahuje prefix face (napr. `/sk/acme-corp/domov`), takže je vždy jasné, v akom prostredí sa nachádza.

### Prepínanie medzi faces

V bočnom paneli na záložke **Faces** sa zobrazujú karty dostupných faces. Kliknutím na kartu sa používateľ prepne do zvolenej face.

### Prvá návšteva súkromnej face

Pri prvej návšteve súkromnej face sa automaticky otvorí panel **Výber role**:
- Používateľ vidí dropdown s dostupnými rolami (napr. FACE_USER, INZERENT, SUBSCRIBER).
- Po výbere a potvrdení sa rola uloží.
- Pri ďalších návštevách sa panel už nezobrazuje.

---

## 3. Navigácia a rozloženie

### Horná lišta (Header)

- **Vľavo**: logo aplikácie.
- **V strede**: ikonová navigácia – Domov + dynamické stránky aktuálnej face + Používatelia.
- **Vpravo**: profilová karta (meno + avatar), akčné tlačidlá (Info, Settings, Menu).

Pre neprihlásených sa zobrazujú len odkazy na Prihlásenie a Registráciu.

### Spodná lišta (Footer)

- Copyright text.
- Pre prihláseného používateľa tlačidlo **Messenger** (otvorí messenger v bočnom paneli).

### Bočný panel

Výsuvný panel s viacerými záložkami:
- **Settings** – prepínač jazyka, odhlásenie.
- **Profile** – úprava profilu.
- **Face role** – výber role (pri súkromných faces).
- **Friend Requests** – žiadosti o priateľstvo.
- **Messenger** – konverzácie a správy.
- **Notifications** – notifikácie.
- **Zoznam blokovaných** – správa zablokovaných používateľov.
- **Faces** – výber face.
- **Pages** – navigačný zoznam stránok.

---

## 4. Jazyky

Aplikácia podporuje 3 jazyky:
- **Slovenčina** (sk)
- **Angličtina** (en)
- **Čeština** (cz)

Prepínanie jazyka je v bočnom paneli (záložka Settings). Pri zmene jazyka sa automaticky preloží aj URL adresa (napr. `/sk/prihlasenie` ↔ `/en/login`).

---

## 5. Domovská stránka

- **Neprihlásený používateľ**: uvítacia stránka s odkazmi na prihlásenie a registráciu.
- **Prihlásený používateľ**: chránená domovská stránka s uvítaním.

---

## 6. Dynamické stránky face

Každá face má vlastné stránky nakonfigurované v admin paneli. Stránky sa zobrazujú v navigácii a obsahujú bloky s rôznymi typmi obsahu:

### Typy obsahových blokov

| Typ | Popis |
|-----|-------|
| **Album** | Fotky a albumy |
| **Ad (Inzercia)** | Inzeráty s cenou a lokalitou |
| **Blog** | Články s dátumom, titulkom a perexom |
| **ChatRoom** | Chatové miestnosti s počtom členov |
| **UserProfile** | Profily používateľov |
| **Reel** | Krátke video (API): prvý reel pre face alebo zoznam v grid/carousel |
| **Story** | Story bubliny (videné/nevidené) |

Každý typ obsahu má tri varianty zobrazenia:
- **Single** – jednotlivá karta.
- **Grid** – mriežka kariet so stránkovaním.
- **Carousel** – horizontálny posuv kariet s navigáciou.

Bloky majú vlastnú hlavičku s akciami (Vytvoriť, Zoznam, Report, Pomoc, Zoradiť, Obľúbené, Nastavenia) a pätičku s navigáciou (Predchádzajúci / Play / Ďalší).

---

## 7. Používatelia

### Zoznam používateľov

Stránka zobrazuje všetkých používateľov s možnosťou prepínania zobrazenia:
- **Mriežka** – karty s avatarmi.
- **Zoznam** – kompaktný zoznam.

Každá karta/riadok zobrazuje meno, email a avatar. Kliknutím sa otvorí detail.

### Detail používateľa

Zobrazuje:
- ID, Email, Meno, Priezvisko.
- Dátum vytvorenia (ak je dostupný).
- Tlačidlo **Späť** pre návrat na zoznam.
- Tlačidlo **Zablokovať používateľa** / **Odblokovať používateľa** (pozri sekciu Blokovanie).

---

## 8. Profil

### Zobrazenie profilu

Stránka zobrazuje základné údaje: ID, Email, Meno, Priezvisko.

### Úprava profilu (bočný panel – záložka Profile)

Používateľ môže upraviť:
- **Meno** a **Priezvisko**.
- **Globálna profilová fotka** – platí vo všetkých faces.
- **Profilová fotka pre aktuálnu face** – prepíše globálnu fotku len v tejto face.

Nahrávanie fotiek kontroluje, že súbor je obrázok.

---

## 9. Žiadosti o priateľstvo

V bočnom paneli na záložke **Friend Requests** sú dve sekcie:

### Prijaté žiadosti

Zoznam žiadostí od iných používateľov. Pri každej žiadosti sú tlačidlá:
- **Prijať** – príjme žiadosť.
- **Odmietnuť** – odmietne žiadosť.

### Pridať priateľa

- Vyhľadávacie pole s debounce (300 ms).
- Zoznam používateľov, ktorých je možné pridať (bez aktuálneho používateľa, existujúcich priateľov a čakajúcich žiadostí).
- Stránkovanie výsledkov (dynamický počet položiek podľa dostupnej výšky – na obrazovku sa zmestí presne toľko, koľko treba).
- Tlačidlo **Odoslať žiadosť** pri každom používateľovi.

---

## 10. Messenger

V bočnom paneli na záložke **Messenger** alebo cez tlačidlo v pätičke.

### Rozloženie

- **Vľavo**: oblasť konverzácie – správy, vstupné pole, žiadosti o správu.
- **Vpravo**: zoznam chatov a žiadostí o správu.

### Funkcie

- Otvorenie existujúceho chatu kliknutím na konverzáciu.
- Prijatie alebo odmietnutie žiadosti o správu.
- Odoslanie správy – **Enter** odošle, **Shift+Enter** nový riadok.
- Reálny čas – správy prichádzajú okamžite.
- Stav pripojenia: Pripájanie / Pripojený / Odpojený.
- Neprečítané správy sa zobrazujú počtom.

---

## 11. Notifikácie

V bočnom paneli na záložke **Notifications**.

- Zoznam notifikácií s názvom, textom, časom a typom.
- Nové notifikácie sa zobrazujú v reálnom čase ako toast oznámenie.
- Ak nie sú žiadne notifikácie: „Zatiaľ žiadne notifikácie".

---

## 12. Blokovanie používateľov

Používateľ môže zablokovať iného používateľa. Zablokovaný používateľ:
- Nemôže posielať správy blokujúcemu.
- Nevidí blokujúceho v zozname používateľov.
- Nemôže odoslať žiadosť o priateľstvo.
- Jeho konverzácie a žiadosti o správu sú skryté.

### Zablokovanie

Na stránke **Detail používateľa** je tlačidlo **Zablokovať používateľa** (červené s ikonou štítu). Po kliknutí sa používateľ okamžite zablokuje a zobrazí sa potvrdzovacie oznámenie.

### Odblokovanie

Odblokovať je možné dvoma spôsobmi:
1. Na stránke **Detail používateľa** – tlačidlo sa zmení na **Odblokovať používateľa** (zelené).
2. V bočnom paneli na záložke **Zoznam blokovaných** – zobrazuje všetkých zablokovaných používateľov s tlačidlom odblokovania pri každom.

### Zoznam blokovaných (bočný panel)

Záložka v bočnom paneli zobrazuje:
- Meno a email každého zablokovaného používateľa.
- Tlačidlo **Odblokovať** (zelená ikona štítu) pri každom zázname.
- Po odblokovaní sa používateľ okamžite odstráni zo zoznamu.

---

## 13. Sledovanie používateľov (Follow / Unfollow)

Používateľ môže sledovať iných používateľov a vidieť, kto ho sleduje.

### Sledovanie (Follow)

Na stránke **Detail používateľa** je tlačidlo **Sledovať používateľa** (modré s ikonou UserPlus). Po kliknutí sa používateľ okamžite pridá medzi sledovaných a zobrazí sa potvrdzovacie oznámenie.

### Zrušenie sledovania (Unfollow)

Zrušiť sledovanie je možné dvoma spôsobmi:
1. Na stránke **Detail používateľa** – tlačidlo sa zmení na **Zrušiť sledovanie** (zelené s ikonou UserCheck).
2. V bočnom paneli na záložke **Sledovaní** – v sekcii „Sledujem" je pri každom používateľovi tlačidlo na zrušenie sledovania.

### Záložka Sledovaní (bočný panel)

Záložka v bočnom paneli zobrazuje dve sekcie:

**Sledujem** – zoznam používateľov, ktorých sledujete:
- Meno a email každého sledovaného.
- Tlačidlo **Unfollow** (ikona UserMinus) pri každom zázname.
- Po zrušení sledovania sa používateľ okamžite odstráni zo zoznamu.

**Sledujúci** – zoznam používateľov, ktorí sledujú vás:
- Meno a email každého sledujúceho.
- Len na čítanie (bez akcie).

---

## 14. AI Chat

Chatové rozhranie pre konverzáciu s AI asistentom.

- História správ zobrazená ako **Vy** a **AI**.
- Vstupné pole + tlačidlo **Odoslať**.
- Stav pripojenia: Pripájanie / Pripojený / Odpojený.
- Pri odoslaní sa AI posiela aj krátky kontext predchádzajúcich správ.

> **Poznámka**: AI Chat nemusí byť priamo dostupný z hlavného menu – závisí od konfigurácie stránok v aktuálnej face.

---

## 15. Albumy

Každý používateľ môže vytvárať vlastné albumy. Album je entita s nasledujúcimi vlastnosťami:

### Vytvorenie a editácia albumu

Kliknutím na ikonu **+** v hlavičke albumového komponentu (Album, AlbumGrid, AlbumCarousel) sa otvorí výsuvný panel s formulárom:

- **Názov** (povinný, max 200 znakov)
- **Popis** (voliteľný, max 2000 znakov)
- **Typ albumu**: Public / Private / Paid (select)
- **Typ médií**: Image / Video (select)
- **Priradenie k Faces** – multiselect s checkboxmi, pri vytváraní predvyplnené všetkými faces

Panel je bez záložiek – zobrazuje sa len formulár (na rozdiel od iných komponentov, kde sú záložky Create/Settings). Po uložení sa panel zatvorí.

Pri editácii sa rovnaký formulár otvorí s predvyplnenými hodnotami existujúceho albumu. Editovať môže len tvorca albumu.

### Zobrazenie albumov

Albumy sa zobrazujú v troch variantoch komponentov:

- **Album** – jedna hlavná fotka s 3 malými thumbnail-mi
- **AlbumGrid** – stránkovaná mriežka albumov (dynamický výpočet cols×rows podľa veľkosti kontajnera)
- **AlbumCarousel** – horizontálny carousel s navigáciou prev/next a bodkovými indikátormi

Kliknutím na album kartu v mriežke alebo carouseli sa používateľ presmeruje na **detail albumu**.

### Detail albumu

Samostatná stránka na URL `/album/{id}` s nasledujúcimi sekciami:

- **Späť** – tlačidlo na návrat
- **Hlavička** – názov, popis, badges (typ albumu + typ médií), meno tvorcu, priradené faces
- **Akcie** – tlačidlá Edit (otvorí inline formulár) a Delete (zmaže album a presmeruje na zoznam)
- **Lajky** – tlačidlo srdce s počtom lajkov, klik lajkne/odlajkne
- **Komentáre** – zoznam komentárov s menom autora a dátumom, formulár na pridanie nového komentára, mazanie vlastných komentárov

### Viditeľnosť

- **Public albumy** vidí každý prihlásený používateľ.
- **Private a Paid albumy** vidí len ich tvorca.
- Na profile iného používateľa sa zobrazujú len jeho public albumy.
- Komentáre a lajky fungujú len na albumoch, ku ktorým má používateľ prístup.

### API endpointy (backend)

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

---

## 16. Reels (krátke videá)

Reel je jedno video s názvom a popisom, s komentármi a lajkmi, podobne ako album v rámci generických grid komponentov.

### Vytvorenie a editácia

Kliknutím na ikonu **+** v hlavičke reel komponentu (**Reel**, **ReelGrid**, **ReelCarousel**) sa otvorí výsuvný panel s formulárom:

- **Názov** (povinný, max 200 znakov)
- **Popis** (voliteľný, max 2000 znakov)
- **Video URL** (povinný, max 1000 znakov) – odkaz na video súbor (napr. MP4)
- **Faces** – voliteľný multiselect: **žiadna zaškrtnutá** = reel je viditeľný na **všetkých** faces; po zaškrtnutí konkrétnych faces je reel viditeľný **len** na týchto faces

Panel je bez záložiek Create/Settings (rovnako ako album/blog). Ikona **zoznamu** v hlavičke presmeruje na stránku `/list/7` (zoznam reels pre daný typ komponentu).

### Zobrazenie v grid layoute

- **Reel** – z API sa načíta prvý reel viditeľný pre aktuálnu face; odkaz vedie na detail
- **ReelGrid** – mriežka kariet s náhľadom videa (metadata), stránkovanie podľa veľkosti kontajnera; klik na kartu → detail
- **ReelCarousel** – horizontálny posuv s rovnakými dátami; v grid layoute sa stránkovanie ovláda aj pätičkou komponentu (Predchádzajúci / Ďalší)

Všetky tieto varianty pri volaní API posielajú **faceId** aktuálne zvolenej face (ak je známa), aby backend vedel filtrovať scoped reels.

### Detail reelu

Stránka na URL **`/reel/{id}`** (v rámci jazykového a face prefixu ako ostatné chránené stránky):

- Prehrávač videa (`videoUrl`)
- Názov, popis, tvorca, zobrazenie priradených faces (ak nejaké sú)
- Lajky a komentáre (rovnaký UX ako pri albume)
- Edit / Delete pre tvorcu

Na načítanie detailu, komentárov a lajkov FE posiela `faceId` aktuálnej face v query stringu (`?faceId=`), aby scoped reels neboli dostupné z „nesprávnej“ face.

### Viditeľnosť (business pravidlá)

- Ak reel **nemá** žiadny záznam v tabuľke priradení k faces → zobrazuje sa na **každej** face.
- Ak má aspoň jedno priradenie → zobrazuje sa **len** na týchto faces.

### API endpointy (backend)

**Reels:**

| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/reels?faceId=` | Zoznam reels (voliteľný filter podľa face) |
| `GET` | `/api/reels/{id}?faceId=` | Detail (pre scoped reels treba správny `faceId`) |
| `GET` | `/api/reels/user/{userId}?faceId=` | Reels daného používateľa |
| `POST` | `/api/reels` | Vytvoriť reel |
| `PUT` | `/api/reels/{id}` | Upraviť (len tvorca) |
| `DELETE` | `/api/reels/{id}` | Zmazať (len tvorca) |

**Komentáre:**

| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/reels/{id}/comments?faceId=` | Komentáre |
| `POST` | `/api/reels/{id}/comments?faceId=` | Pridať komentár |
| `PUT` | `/api/reels/{id}/comments/{cid}` | Upraviť komentár |
| `DELETE` | `/api/reels/{id}/comments/{cid}` | Zmazať komentár |

**Lajky:**

| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/reels/{id}/likes?faceId=` | Zoznam lajkov |
| `POST` | `/api/reels/{id}/likes?faceId=` | Lajk |
| `DELETE` | `/api/reels/{id}/likes?faceId=` | Odlajk |

### Redis fronta a plánovač úloh (backend, BullMQ-like)

Po vytvorení reelu API zaradí do Redis:

1. **Okamžitá úloha** `reel.postprocess` (napr. miesto pre budúce spracovanie videa).
2. **Odložená úloha** rovnakého typu s oneskorením ~1 minúta (demonstrácia delayed jobs).

Implementácia: **StackExchange.Redis** – zoznam `bedemo:jobs:ready` (FIFO) a zoradená množina `bedemo:jobs:delayed` (score = čas spustenia UTC v ms). Hostovaná služba `RedisJobWorkerService` v cykle presúva splatné delayed joby do ready fronty a spracováva ich (aktuálne len logovanie).

Redis je git submodule **`redis_demo`** (rovnaký model ako **`db_demo`**): vlastný `docker-compose.yml`, skripty `start-redis.sh` atď. Kontajner `be-demo-dev` sa pripája na **`host.docker.internal:6379`**. Klon: `git submodule update --init redis_demo`. Podrobnosti: [`redis-subrepo-sk.md`](./redis-subrepo-sk.md). Ak Redis nie je dostupný alebo je `Redis:Configuration` prázdny (appsettings / Testing), používa sa **NoOp** fronta.

---

## 17. Blog

Každý používateľ môže vytvárať blogové príspevky. Blog je entita priradená k jednej konkrétnej Face.

### Vytvorenie a editácia blogu

Kliknutím na ikonu **+** v hlavičke blogového komponentu (Blog, BlogGrid, BlogCarousel) sa otvorí výsuvný panel s formulárom:

- **Názov** (povinný, max 200 znakov)
- **Face** – povinný výber jednej face (select, nie multiselect)
- **Obsah** – WYSIWYG editor (react-quill-new) s formátovaním: nadpisy, tučné, kurzíva, zoznamy, citáty, kód, odkazy. Obrázky v obsahu nie sú povolené.
- **Obrázky** – max 3 URL adries obrázkov pripojených k blogu (pridanie/odoberanie cez URL input)

Panel je bez záložiek – zobrazuje sa len formulár (rovnako ako u albumov). Po uložení sa panel zatvorí.

Pri editácii sa rovnaký formulár otvorí s predvyplnenými hodnotami vrátane HTML obsahu v editore. Editovať môže len tvorca blogu.

### Zobrazenie blogov

Blogy sa zobrazujú v troch variantoch komponentov:

- **Blog** – jeden príspevok
- **BlogGrid** – stránkovaná mriežka blogov (dynamický výpočet cols×rows podľa veľkosti kontajnera)
- **BlogCarousel** – horizontálny carousel s navigáciou prev/next a bodkovými indikátormi

Kliknutím na blog kartu v mriežke alebo carouseli sa používateľ presmeruje na **detail blogu**.

### Detail blogu

Samostatná stránka na URL `/blog/{id}` s nasledujúcimi sekciami:

- **Späť** – tlačidlo na návrat
- **Hlavička** – názov, badge s face, meno tvorcu, dátum vytvorenia
- **Obrázky** – galéria pripojených obrázkov (max 3)
- **Obsah** – HTML obsah z WYSIWYG editora (formátovaný text s nadpismi, zoznammi, odkazmi, citátmi)
- **Akcie** – tlačidlá Edit (otvorí inline formulár s WYSIWYG editorom) a Delete (zmaže blog a presmeruje na zoznam)
- **Lajky** – tlačidlo srdce s počtom lajkov, klik lajkne/odlajkne
- **Komentáre** – zoznam komentárov s menom autora a dátumom, formulár na pridanie nového komentára, mazanie vlastných komentárov

### Filtrovanie podľa Face

Blogy sú vždy priradené k jednej Face. API endpoint `GET /api/blogs?faceId={faceId}` umožňuje filtrovať blogy podľa vybranej face.

### API endpointy (backend)

**Blogy:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/blogs?faceId={faceId}` | Zoznam blogov (voliteľný filter podľa face) |
| `GET` | `/api/blogs/{id}` | Detail blogu |
| `POST` | `/api/blogs` | Vytvoriť blog |
| `PUT` | `/api/blogs/{id}` | Upraviť blog (len creator) |
| `DELETE` | `/api/blogs/{id}` | Zmazať blog (len creator) |

**Komentáre:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/blogs/{id}/comments` | Komentáre blogu |
| `POST` | `/api/blogs/{id}/comments` | Pridať komentár |
| `PUT` | `/api/blogs/{id}/comments/{cid}` | Upraviť komentár |
| `DELETE` | `/api/blogs/{id}/comments/{cid}` | Zmazať komentár |

**Lajky:**
| Metóda | Endpoint | Popis |
|--------|----------|-------|
| `GET` | `/api/blogs/{id}/likes` | Zoznam lajkov |
| `POST` | `/api/blogs/{id}/likes` | Lajknúť blog |
| `DELETE` | `/api/blogs/{id}/likes` | Odlajknúť blog |

---

## 18. Predvolené prihlasovacie údaje

- **Email**: `admin@admin.com`
- **Heslo**: `admin`
