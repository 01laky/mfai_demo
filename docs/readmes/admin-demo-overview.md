# Admin application (`admin_demo`) — functional overview

## Overview

The admin app manages the whole platform: users, faces (tenants), pages, and content. It includes an AI chat assistant.

Typical dev URL: **http://localhost:8082**.

---

## 1. Sign-in

Fields:
- **Email** (required)
- **Password** (min 4 characters)
- **“Stay signed in”** — optional; longer JWT when checked (same mechanism as `fe_demo`). See [**authentication-and-sessions.md**](../guides/authentication-and-sessions.md).
- **Sign in** button

Success → Dashboard. Failure → error toast.

Unauthenticated visits to protected routes redirect to sign-in, then return to the original URL.

---

## 2. Layout and navigation

### Header

- **Hamburger** — toggles sidebar on small screens.
- **Title:** Admin Demo.
- **Language** (`sk` / `en` / `cz`).
- Admin **email** + **Sign out**.

### Left sidebar

- **Dashboard**
- **Users**
- **Faces**
- **AI Chat**

On mobile the sidebar is an overlay.

---

## 3. Languages

Three locales: **Slovak** (`sk`), **English** (`en`), **Czech** (`cz`). Toggle in the header; URLs localize (e.g. dashboard paths per locale).

---

## 4. Dashboard

- Greeting with signed-in email.
- **Cards:** Users count, Faces count, Friend requests count, Messages count — each links into the module.
- **Quick actions:** Users, Faces.

---

## 5. Users

### List

Search, Refresh, **Create user**, sortable paginated table.

| Column | Description |
|--------|-------------|
| ID | Click → detail |
| Email | |
| First name | |
| Last name | |
| Created | |
| Actions | Edit |

### Detail

ID, email, names, created date.

### Create

Email, first name, last name, password, confirm password → back to list on success.

### Edit

Same fields; password optional (blank = unchanged).

> User delete is not exposed in admin UI.

---

## 6. Faces

A **face** is a tenant space with its own pages and settings.

### List

Search, Refresh, **Create face**, sortable table.

| Column | Description |
|--------|-------------|
| ID | Click → detail |
| Index | URL slug (e.g. `acme-corp`) |
| Name | Display name |
| Description | Short text |
| Color | Badge |
| Visibility | Public / Private |
| Actions | Edit |

### Detail

ID, index, name, visibility, description, color, timestamps, embedded **Pages** list.

### Create

Index, name, description, color, **Public access** toggle. Default pages are created (Home, List, Detail; private faces also get Wall).

### Edit

Same fields plus:

#### Background gradient editor

Gradient type (linear/radial), angle, color stops, animation toggle and speed.

#### Pages

Table of pages with **Create page**.

> Face delete is not exposed in admin UI.

---

## 7. Pages

Pages belong to a face; managed from face detail/edit.

### Create

Page type (Home, List, Detail, Wall), name, path, sort index, description.

#### Route translations

Per-locale URL segments (each locale can use its own slug for the same logical page).

### Detail / Edit

Same fields + translation editor.

#### Grid layout editor

Add block, drag/drop, resize, rename, delete, assign component type.

##### Component categories

| Category | Description |
|----------|-------------|
| Albums | Single / grid / carousel |
| Ads | Classifieds |
| Blog | Articles |
| Chat rooms | Chat tiles |
| Profiles | User profiles |
| Reels | Short video |
| Stories | Story bubbles |

Each category: **single**, **grid**, **carousel**.

### Delete page

**Delete** with confirmation in the pages table.

---

## 8. AI Chat

Sidebar **AI Chat**: connection state, **You** / **AI** history, input, **Send**, “AI is typing…” indicator, long-running notice. History is in-memory for the browser session (refresh clears it).

---

## 9. Typical admin workflow

1. Sign in.
2. Dashboard metrics.
3. Users — create/edit as needed.
4. Faces — create, tune gradient and visibility.
5. Pages — routes, translations, grid layout.
6. AI Chat — optional assistance.

---

## 10. Albums (API)

REST CRUD; model: Album, AlbumFace, AlbumComment, AlbumLike. Visibility: Public (any signed-in), Private/Paid (creator for now).

Endpoints mirror [`fe-demo-overview.md`](./fe-demo-overview.md) album table (`/api/albums` …).

---

## 11. Reels (API) and Redis

Reel, ReelFace (no rows = global across faces), ReelComment, ReelLike. POST enqueues Redis jobs. Submodule **`redis_demo`**, `Redis__Configuration=host.docker.internal:6379`. Keys `bedemo:jobs:ready`, `bedemo:jobs:delayed`. See [**redis-subrepo.md**](./redis-subrepo.md) and `redis_demo/README.md`.

---

## 12. Blog (API)

Blog bound to one Face; HTML content; max 3 images; comments/likes. Endpoints under `/api/blogs` (see `fe_demo` overview for pattern).

---

## 13. Default demo credentials

- **Email:** `admin@admin.com`
- **Password:** `admin`
