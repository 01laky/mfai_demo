# MFAI Demo - Multi-Application Demo Project

A comprehensive monorepo containing multiple applications for demonstrating a full-stack development setup with Docker, microservices architecture, and modern web technologies.

## Overview

This project demonstrates a complete development environment with:
- **Backend API** (ASP.NET Core) - RESTful API with OAuth2 authentication
- **Frontend Application** (React + TypeScript) - User-facing application
- **Admin Panel** (React + TypeScript) - Administrative interface
- **Database** (PostgreSQL) - Relational database
- **AI Demo Service** (Python gRPC) - AI service with gRPC interface
- **Logger Demo** (Dozzle) - Real-time log viewer for all containers

All services are containerized with Docker and managed via comprehensive bash scripts.

## Project Structure

```
_mfai_demo/
├── be_demo/              # Backend API (ASP.NET Core, PostgreSQL, OAuth2)
├── fe_demo/              # Frontend Application (React, TypeScript, Vite)
├── admin_demo/           # Admin Panel (React, TypeScript, Vite)
├── db_demo/              # PostgreSQL Database Setup
├── ai_demo/              # AI Demo gRPC Service (Python)
├── logger_demo/          # Logger Demo - Dozzle Log Viewer
├── docker-compose.dev.yml # Root Docker Compose for development
├── start-all-dev.sh      # Start all services with live status screen
├── stop-all-dev.sh       # Stop all services
├── clear-all-dev.sh      # Clear all containers and volumes
├── restart-all-dev.sh    # Restart all services with rebuild
├── status-all.sh         # Show status of all services
├── rebuild-all-dev.sh    # Rebuild all Docker images
└── test-all.sh           # Run tests for all services
```

## Applications

### Backend API (`be_demo`)

**Technology**: ASP.NET Core 10.0, PostgreSQL, Entity Framework Core

**Features**:
- OAuth2 token-based authentication
- JWT token generation and validation
- User registration and login
- RESTful API endpoints
- Swagger/OpenAPI documentation
- Structured logging with Seq
- SignalR for real-time communication
- Health checks for AI services

**Ports**:
- HTTP: `8000`
- HTTPS: `8001`

**Documentation**: See [`be_demo/README.md`](./be_demo/README.md) for detailed documentation.

### Frontend Application (`fe_demo`)

**Technology**: React 18, TypeScript, Vite

**Features**:
- User registration and login
- Protected routes
- Internationalization (English, Slovak, Czech)
- Auto-generated API client from Swagger
- Type-safe API calls
- Responsive design with Bootstrap

**Port**: `8081`

**Documentation**: See [`fe_demo/README.md`](./fe_demo/README.md) for detailed documentation.

### Admin Panel (`admin_demo`)

**Technology**: React 18, TypeScript, Vite

**Features**:
- Admin dashboard
- CRUD operations for users, faces, pages
- OAuth2 login
- Data tables with sorting and pagination
- Form validation
- Internationalization support

**Port**: `8082`

**Documentation**: See [`admin_demo/README.md`](./admin_demo/README.md) for detailed documentation.

### Database (`db_demo`)

**Technology**: PostgreSQL 16, pgAdmin 4

**Configuration**:
- Host: `localhost` (from host) or `host.docker.internal` (from containers)
- Port: `5432`
- Database: `bedemo`
- Username: `bedemo_user`
- Password: `bedemo_password`

**pgAdmin Access**:
- **URL**: http://localhost:5050
- **Email**: `admin@admin.com`
- **Password**: `admin`

**Documentation**: See [`db_demo/README.md`](./db_demo/README.md) for detailed documentation.

### AI Demo Service (`ai_demo`)

**Technology**: Python 3.11, gRPC, Protocol Buffers

**Features**:
- gRPC server with health check endpoint
- Health check RPC method
- Integration with backend API for startup health verification

**Port**: `50051` (gRPC)

**Documentation**: See [`ai_demo/README.md`](./ai_demo/README.md) for detailed documentation.

### Logger Demo (`logger_demo`)

**Technology**: Dozzle (Docker log viewer)

**Features**:
- Real-time log viewing for all containers
- Web UI for log management
- Filtering and search capabilities
- Auto-discovery of containers

**Port**: `8080`

**Documentation**: See [`logger_demo/README.md`](./logger_demo/README.md) for detailed documentation.

## Quick Start

### Prerequisites

- **Docker** & **Docker Compose** - For containerization
- **Bash** - For running management scripts (macOS/Linux)
- **Git** - For version control

### Start All Services

The easiest way to start all services:

```bash
./start-all-dev.sh
```

This script will:
1. Start all services in the correct order
2. Display a live status screen (refreshes every 5 seconds)
3. Show container status and accessibility

**Note**: Press `Ctrl+C` to exit the status screen. Services will continue running.

### Access Applications

Once all services are started, access them at:

- **Backend API**: http://localhost:8000
- **Swagger UI**: http://localhost:8000/swagger
- **Frontend**: http://localhost:8081
- **Admin Panel**: http://localhost:8082
- **Seq Logging UI**: http://localhost:5341
- **Logger Demo (Dozzle)**: http://localhost:8080
- **pgAdmin**: http://localhost:5050
- **Database**: `localhost:5432`

### Default Login Credentials

- **Email**: `admin@admin.com`
- **Password**: `admin`
- **OAuth2 Client ID**: `be-demo-client`
- **OAuth2 Client Secret**: `be-demo-secret-very-strong-key`

## Management Scripts

### Root-Level Scripts

All root-level scripts are located in the root directory:

#### Start All Services

```bash
./start-all-dev.sh
```

Starts all services with a live status screen that refreshes every 5 seconds.

#### Stop All Services

```bash
./stop-all-dev.sh
```

Stops all containers gracefully.

#### Clear All Services

```bash
./clear-all-dev.sh
```

Removes all containers and volumes. **⚠️ Warning**: This will delete all data!

#### Restart All Services

```bash
./restart-all-dev.sh
```

Stops all services, rebuilds Docker images, and starts all services again.

#### Show Status

```bash
./status-all.sh
```

Displays comprehensive status of all services (containers, accessibility, ports).

#### Rebuild All Images

```bash
./rebuild-all-dev.sh
```

Performs a clean rebuild of all Docker images (no cache). **Note**: This only builds images, it does NOT start containers.

#### Run All Tests

```bash
./test-all.sh
```

Runs tests for all services and displays a summary.

### Service-Specific Scripts

Each service has its own scripts in its directory:

- `start-dev.sh` - Start service
- `stop-dev.sh` - Stop service
- `clear-dev.sh` - Clear containers and volumes
- `rebuild-dev.sh` - Rebuild Docker images

See each service's README for details.

## Docker Services

### Containers

All services run as Docker containers with the following names:

- `postgres-dev` - PostgreSQL database
- `be-demo-dev` - Backend API
- `fe-demo-dev` - Frontend application
- `admin-demo-dev` - Admin panel
- `seq-dev` - Seq logging server
- `ai-demo-dev` - AI Demo gRPC service
- `dozzle-dev` - Logger Demo (Dozzle)

### Network

All services run on the `mfai_demo_dev-network` Docker network for internal communication.

### Volumes

- `mfai_demo_seq-data` - Seq logging data
- `mfai_demo_be-demo-https` - Backend HTTPS certificates
- `db_demo_postgres-data` - PostgreSQL data
- Service-specific node_modules and cache volumes

## Development Workflow

### Typical Development Flow

1. **Start all services**:
   ```bash
   ./start-all-dev.sh
   ```

2. **Make code changes** in any service directory

3. **Test changes**:
   - Manual testing via web interfaces
   - Run tests: `./test-all.sh`
   - Check logs via Dozzle at http://localhost:8080

4. **View logs**:
   - Dozzle: http://localhost:8080
   - Seq: http://localhost:5341
   - Docker logs: `docker logs <container-name>`

5. **Stop services** when done:
   ```bash
   ./stop-all-dev.sh
   ```

### Rebuilding After Code Changes

If you make significant changes (e.g., dependencies, Docker configuration):

```bash
# Rebuild all images
./rebuild-all-dev.sh

# Start all services
./start-all-dev.sh
```

### Cleaning Up

To completely clean up (remove all containers, volumes, and images):

```bash
./clear-all-dev.sh
```

**⚠️ Warning**: This will delete all data including the database!

## Architecture

### Service Communication

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
┌──────▼──────┐   ┌──────▼──────┐
│   Frontend  │   │   Admin     │
│  (port 8081)│   │ (port 8082) │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                │
       ┌────────▼────────┐
       │   Backend API   │
       │  (port 8000)    │
       └────────┬────────┘
                │
       ┌────────┼────────┐
       │        │        │
┌──────▼──┐ ┌──▼───┐ ┌──▼────┐
│Database │ │ Seq  │ │AI Demo│
│(5432)   │ │(5341)│ │(50051)│
└─────────┘ └──────┘ └───────┘

       ┌──────────────┐
       │ Logger Demo  │
       │ (port 8080)  │
       │  (reads all) │
       └──────────────┘
```

### Technology Stack

**Backend**:
- ASP.NET Core 10.0
- Entity Framework Core
- PostgreSQL
- Serilog + Seq
- SignalR

**Frontend**:
- React 18
- TypeScript
- Vite
- React Router
- React Query
- Bootstrap

**Infrastructure**:
- Docker & Docker Compose
- PostgreSQL
- gRPC (Python)
- Dozzle (log viewer)

## Git Structure

### Monorepo with Submodules

Each application has its own git repository (submodule-like structure):

- `be_demo/` - Backend repository
- `fe_demo/` - Frontend repository
- `admin_demo/` - Admin repository
- `db_demo/` - Database setup repository
- `ai_demo/` - AI Demo repository
- `logger_demo/` - Logger Demo repository

The root directory also has a git repository for managing:
- Root-level Docker Compose configuration
- Management scripts (`start-all-dev.sh`, `stop-all-dev.sh`, etc.)
- Project documentation

### Working with Git

**Commit changes in submodules**:
```bash
cd be_demo
git add .
git commit -m "Your message"
```

**Commit changes in root**:
```bash
git add .
git commit -m "Your message"
```

**Commit all (root and submodules)**:
Commit changes in each submodule first, then commit root repository.

## Configuration

### Environment Variables

Each service uses environment variables configured in:
- `docker-compose.dev.yml` (root)
- Service-specific `docker-compose.yml` files
- `.env` files (if present)

See each service's README for specific configuration details.

### Database Connection

Default connection string:
```
Host=host.docker.internal;Port=5432;Database=bedemo;Username=bedemo_user;Password=bedemo_password
```

- **From Docker containers**: Use `host.docker.internal`
- **From localhost**: Use `localhost`

### Port Mapping

All services use the following ports (configurable):

| Service | Port | Description |
|---------|------|-------------|
| Database | 5432 | PostgreSQL |
| Backend HTTP | 8000 | HTTP API |
| Backend HTTPS | 8001 | HTTPS API |
| Frontend | 8081 | User-facing app |
| Admin | 8082 | Admin panel |
| Seq | 5341 | Logging UI |
| AI Demo | 50051 | gRPC service |
| Logger Demo | 8080 | Dozzle log viewer |
| pgAdmin | 5050 | PostgreSQL admin UI |

## Testing

### Run All Tests

```bash
./test-all.sh
```

This script:
1. Runs tests for backend (ASP.NET Core)
2. Runs tests for frontend (Vitest)
3. Runs tests for admin (Vitest)
4. Displays a summary of all test results

### Run Service-Specific Tests

**Backend**:
```bash
cd be_demo/BeDemo.Api.Tests
dotnet test
```

**Frontend**:
```bash
cd fe_demo
yarn test
```

**Admin**:
```bash
cd admin_demo
yarn test
```

## Troubleshooting

### Port Already Allocated

If a port is already in use:

```bash
# Find process using port
lsof -ti:PORT_NUMBER

# Kill process
lsof -ti:PORT_NUMBER | xargs kill -9

# Or stop conflicting containers
./stop-all-dev.sh
```

### Container Not Starting

1. Check logs:
   ```bash
   docker logs <container-name>
   ```

2. Check status:
   ```bash
   ./status-all.sh
   ```

3. Try rebuilding:
   ```bash
   ./rebuild-all-dev.sh
   ./start-all-dev.sh
   ```

### Database Connection Failed

1. Ensure database is running:
   ```bash
   docker ps | grep postgres-dev
   ```

2. Check connection string in `docker-compose.dev.yml`

3. Verify database credentials match `db_demo` configuration

### Services Not Communicating

1. Verify all services are on the same network:
   ```bash
   docker network inspect mfai_demo_dev-network
   ```

2. Check service names in connection strings

3. Ensure services are started in the correct order (database first)

## Documentation

Each service has comprehensive documentation:

- **[Backend API](./be_demo/README.md)** - Detailed backend documentation
- **[Frontend](./fe_demo/README.md)** - Frontend documentation
- **[Admin Panel](./admin_demo/README.md)** - Admin panel documentation
- **[Database](./db_demo/README.md)** - Database setup and configuration
- **[AI Demo](./ai_demo/README.md)** - AI Demo gRPC service documentation
- **[Logger Demo](./logger_demo/README.md)** - Logger Demo documentation

## Additional Resources

### Service-Specific Documentation

- **Backend**: See `be_demo/SEQ_LOGGING.md` for Seq logging setup
- **Frontend**: See `fe_demo/DOCKER.md` for Docker-specific documentation
- **Admin**: See `admin_demo/DOCKER.md` for Docker-specific documentation

### Development Tools

- **Dozzle**: http://localhost:8080 - View all container logs
- **Seq**: http://localhost:5341 - Structured log analysis
- **Swagger**: http://localhost:8000/swagger - API documentation

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]

## Support

For issues or questions:
1. Check the service-specific README files
2. Check troubleshooting section above
3. Review Docker logs: `docker logs <container-name>`
4. Check status: `./status-all.sh`
