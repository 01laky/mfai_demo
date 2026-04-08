# Redis – submodule `redis_demo`

Redis pre backend job frontu je **samostatný git submodule**, rovnako ako **`db_demo`**.

## Umiestnenie

```
_mfai_demo/redis_demo/
```

- Vlastný GitHub repozitár (v `.gitmodules` je `https://github.com/01laky/redis_demo.git` – uprav podľa reality).
- Root monorepo: `git submodule update --init redis_demo`

## Spustenie

```bash
cd redis_demo
./start-redis.sh
```

Alebo z rootu cez `./start-all-dev.sh` (po DB sa spustí aj Redis).

## Pripojenie backendu

Root **`docker-compose.dev.yml`** → `be-demo-dev`:

- `Redis__Configuration=host.docker.internal:6379`
- `extra_hosts: host.docker.internal:host-gateway`

`redis_demo` publikuje **6379:6379**, takže z kontajnera BE ide traffic na hosta a do `redis-dev`.

## Súbory v `redis_demo`

| Súbor | Účel |
|--------|------|
| `docker-compose.yml` | `redis:7-alpine`, volume, healthcheck |
| `start-redis.sh` / `stop-redis.sh` / `clear-redis.sh` | Ako `db_demo` skripty |
| `README.md` | Anglický popis pre samostatné repo |

## Nový klon monorepa

```bash
git clone --recurse-submodules <root-url>
# alebo po clone:
git submodule update --init redis_demo
```

## Prvé zverejnenie `redis_demo` ako repo

1. Na GitHub vytvor repozitár `redis_demo` (prázdny).
2. V adresári `redis_demo`: `git init`, `git add .`, commit, `remote add`, `push`.
3. V root `_mfai_demo`: ak si predtým nemal submodule, `git submodule add <url> redis_demo` (alebo už máš `.gitmodules` + commitni smerovanie submodule na správny commit).

Podrobnejší postup je v **`GIT_SUBMODULES_SETUP.md`** v koreni monorepa (dopln sekciu pre `redis_demo` rovnako ako `db_demo`).
