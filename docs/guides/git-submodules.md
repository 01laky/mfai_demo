# Git Submodules Setup Guide

## Postup vytvorenia GitHub repozitárov so submodulmi

### 1. Vytvoriť repozitáre na GitHub

Na GitHub vytvor **7+ súkromných repozitárov** (root + submoduly):

1. **Root repo**: `_mfai_demo` (alebo `mfai-demo`)
2. **Submoduly**:
   - `be_demo`
   - `fe_demo`
   - `admin_demo`
   - `ai_demo`
   - `db_demo`
   - `redis_demo`

### 2. Nastaviť remote URL v každom submodule

Pre každý submodul nastav remote URL (nahraď `YOUR_USERNAME` svojím GitHub username):

```bash
# Backend
cd be_demo
git remote add origin https://github.com/YOUR_USERNAME/be_demo.git
git branch -M main
git push -u origin main

# Frontend
cd ../fe_demo
git remote add origin https://github.com/YOUR_USERNAME/fe_demo.git
git branch -M main
git push -u origin main

# Admin
cd ../admin_demo
git remote add origin https://github.com/YOUR_USERNAME/admin_demo.git
git branch -M main
git push -u origin main

# AI Demo
cd ../ai_demo
git remote add origin https://github.com/YOUR_USERNAME/ai_demo.git
git branch -M main
git push -u origin main

# Database
cd ../db_demo
git remote add origin https://github.com/YOUR_USERNAME/db_demo.git
git branch -M main
git push -u origin main

# Redis (job queue)
cd ../redis_demo
git remote add origin https://github.com/YOUR_USERNAME/redis_demo.git
git branch -M main
git push -u origin main
```

### 3. Aktualizovať `.gitmodules` s reálnymi GitHub URL

Uprav `.gitmodules` súbor - nahraď `YOUR_USERNAME` skutočným username:

```bash
# V root adresári
nano .gitmodules  # alebo použi svoj editor
```

### 4. Registrovať submoduly v root repozitári

```bash
cd /Users/ladislavkostolny/Soft/_mfai_demo

# Pridať submoduly
git submodule add -f https://github.com/YOUR_USERNAME/be_demo.git be_demo
git submodule add -f https://github.com/YOUR_USERNAME/fe_demo.git fe_demo
git submodule add -f https://github.com/YOUR_USERNAME/admin_demo.git admin_demo
git submodule add -f https://github.com/YOUR_USERNAME/ai_demo.git ai_demo
git submodule add -f https://github.com/YOUR_USERNAME/db_demo.git db_demo
git submodule add -f https://github.com/YOUR_USERNAME/redis_demo.git redis_demo

# Alebo ak už existujú, len aktualizovať .gitmodules a commitnúť:
git add .gitmodules
git commit -m "Add git submodules configuration"
```

### 5. Nastaviť remote URL v root repozitári

```bash
# V root adresári
git remote add origin https://github.com/YOUR_USERNAME/_mfai_demo.git
git branch -M main
git add .gitmodules
git commit -m "Configure git submodules"
git push -u origin main
```

### 6. Pushnúť submoduly do root repozitára

```bash
# Root repo sa bude odkazovať na konkrétne commity v submoduloch
git add .gitmodules
git commit -m "Update submodule references"
git push
```

## Dôležité poznámky

- **Root repo obsahuje iba odkazy na commity** v submoduloch, nie samotný kód
- Pri clone root repa treba použiť `git clone --recursive` alebo `git submodule update --init --recursive`
- Pri update submodulu treba commitnúť zmenu v root repozitári

## Použitie po setup

```bash
# Clone celého projektu so submodulmi
git clone --recursive https://github.com/YOUR_USERNAME/_mfai_demo.git

# Alebo ak už máš root repo:
git submodule update --init --recursive

# Update všetkých submodulov
git submodule update --remote

# Commitnutie zmien v submodule
cd be_demo
git add .
git commit -m "Changes"
git push
cd ..
git add be_demo
git commit -m "Update be_demo submodule"
git push
```
