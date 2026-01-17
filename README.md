# MFAI Demo - Multi-Application Demo Project

This is a monorepo containing multiple applications, each with its own git repository.

## Project Structure

```
_mfai_demo/
├── be_demo/          # Backend API (ASP.NET Core, PostgreSQL, OAuth2)
├── fe_demo/          # Frontend Application (React, TypeScript)
├── admin_demo/       # Admin Application (React, TypeScript)
├── db_demo/          # PostgreSQL Database Setup
└── docker-compose.dev.yml  # Docker Compose for development
```

## Applications

### Backend API (`be_demo`)
- **Technology**: ASP.NET Core 10.0, PostgreSQL, Entity Framework Core
- **Features**: OAuth2 authentication, JWT tokens, REST API, SignalR
- **Port**: 8000 (HTTP), 8001 (HTTPS)
- **Database**: PostgreSQL (via `db_demo`)

### Frontend (`fe_demo`)
- **Technology**: React 19, TypeScript, Vite
- **Features**: OAuth2 login, i18n, React Router
- **Port**: 8081

### Admin (`admin_demo`)
- **Technology**: React 19, TypeScript, Vite
- **Features**: Admin dashboard, CRUD operations, OAuth2 login
- **Port**: 8082

### Database (`db_demo`)
- **Technology**: PostgreSQL 16
- **Port**: 5432
- **Database**: `bedemo`
- **User**: `bedemo_user`

## Development Setup

### Prerequisites
- Docker & Docker Compose
- Node.js (for local development, optional)

### Quick Start

1. **Start Database:**
   ```bash
   cd db_demo
   docker-compose up -d
   ```

2. **Start All Services:**
   ```bash
   docker-compose -f docker-compose.dev.yml up -d
   ```

3. **Access Applications:**
   - Backend API: http://localhost:8000
   - Swagger: http://localhost:8000/swagger
   - Frontend: http://localhost:8081
   - Admin: http://localhost:8082

### Default Login Credentials

- **Email**: `admin@admin.com`
- **Password**: `admin`
- **OAuth2 Client ID**: `be-demo-client`
- **OAuth2 Client Secret**: `be-demo-secret-very-strong-key`

## Git Structure

Each application has its own git repository:
- `be_demo/.git` - Backend repository
- `fe_demo/.git` - Frontend repository
- `admin_demo/.git` - Admin repository
- `db_demo/.git` - Database setup repository

The root directory also has a git repository for managing the overall project structure and Docker Compose configuration.

## Docker Services

- `postgres-dev` - PostgreSQL database
- `be-demo-dev` - Backend API
- `fe-demo-dev` - Frontend application
- `admin-demo-dev` - Admin application
- `seq-dev` - Seq logging server (optional)

## Scripts

- `restart-all-dev.sh` - Restart all development containers
- `db_demo/start-db.sh` - Start database
- `db_demo/stop-db.sh` - Stop database

## Notes

- Each subdirectory is a separate git repository
- The root `.gitignore` excludes `.git` folders in subdirectories
- All applications use Docker for development
- Backend uses PostgreSQL (migrated from SQLite)
- Frontend and Admin use generated TypeScript types from Swagger/OpenAPI
