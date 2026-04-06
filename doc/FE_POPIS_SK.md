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

Po úspešnom prihlásení sa používateľ dostane na domovskú stránku aktuálnej face.

### Automatické odhlásenie

Ak platnosť prihlásenia vyprší, aplikácia používateľa automaticky odhlási a presmeruje na prihlásenie s hláškou „Platnosť prihlásenia vypršala".

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
| **Reel** | Krátke video karty s autorom a lajkami |
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

## 15. Predvolené prihlasovacie údaje

- **Email**: `admin@admin.com`
- **Heslo**: `admin`
