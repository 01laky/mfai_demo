# Local development accounts and passwords

Accounts match the backend code in `many_faces_backend`: `Scripts/InitializeDatabase.cs` (bootstrap super-admin), `Scripts/DatabaseSeeder.cs` → `SeedUsersAsync` (seeded admin and user accounts), and `BeDemo.Api.Tests/IntegrationTestSeed.cs` (integration tests only).

**Typical local PostgreSQL after the API starts:** rows below reference the initializer, `SeedUsersAsync`, or test seeding. Rows marked **tests only** are not created by `docker compose` / normal API startup — they exist only when the test host runs `IntegrationTestSeed`.

## 1. Super admins and admins (global role)

| Email                             | Global role   | Password     | Source                                                   |
| --------------------------------- | ------------- | ------------ | -------------------------------------------------------- |
| `admin@admin.com`                 | `SUPER_ADMIN` | `admin`      | Initializer (`DatabaseInitializer`) on API startup       |
| `admin1@demo.com`                 | `ADMIN`       | `admin`      | `SeedUsersAsync`                                         |
| `admin2@demo.com`                 | `ADMIN`       | `admin`      | `SeedUsersAsync`                                         |
| `integration-superadmin@test.com` | `SUPER_ADMIN` | `Test123!@#` | Tests only (`IntegrationTestSeed.EnsureSuperAdminAsync`) |
| `integration-admin@test.com`      | `ADMIN`       | `Test123!@#` | Tests only (`IntegrationTestSeed.EnsureAsync`)           |

## 2. Regular users (`USER`)

All use the same password **`user123`**. Emails are `user01@demo.com` through `user30@demo.com` (`user` + two digits + `@demo.com`).

| Email             | Password  | Display name (seed) |
| ----------------- | --------- | ------------------- |
| `user01@demo.com` | `user123` | Ján Horváth         |
| `user02@demo.com` | `user123` | Peter Kováč         |
| `user03@demo.com` | `user123` | Martin Varga        |
| `user04@demo.com` | `user123` | Tomáš Tóth          |
| `user05@demo.com` | `user123` | Lukáš Nagy          |
| `user06@demo.com` | `user123` | Marek Baláž         |
| `user07@demo.com` | `user123` | Michal Molnár       |
| `user08@demo.com` | `user123` | Ondrej Szabó        |
| `user09@demo.com` | `user123` | Dávid Novák         |
| `user10@demo.com` | `user123` | Jakub Fekete        |
| `user11@demo.com` | `user123` | Mária Bílik         |
| `user12@demo.com` | `user123` | Anna Krajčír        |
| `user13@demo.com` | `user123` | Katarína Kučera     |
| `user14@demo.com` | `user123` | Jana Polák          |
| `user15@demo.com` | `user123` | Zuzana Valent       |
| `user16@demo.com` | `user123` | Monika Hudák        |
| `user17@demo.com` | `user123` | Lucia Šimko         |
| `user18@demo.com` | `user123` | Petra Jurčo         |
| `user19@demo.com` | `user123` | Simona Hruška       |
| `user20@demo.com` | `user123` | Lenka Majer         |
| `user21@demo.com` | `user123` | Róbert Lacko        |
| `user22@demo.com` | `user123` | Štefan Gajdoš       |
| `user23@demo.com` | `user123` | Pavol Rusnák        |
| `user24@demo.com` | `user123` | Daniel Sedlák       |
| `user25@demo.com` | `user123` | Matúš Vrábel        |
| `user26@demo.com` | `user123` | Filip Haluška       |
| `user27@demo.com` | `user123` | Andrej Mišík        |
| `user28@demo.com` | `user123` | Samuel Bartoš       |
| `user29@demo.com` | `user123` | Richard Čierny      |
| `user30@demo.com` | `user123` | Patrik Zelený       |
