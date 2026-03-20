# Docker Deployment Guide

## Overview
This project uses Docker Compose to provide a containerized environment for the Transaction Processing Platform with PostgreSQL database and frontend service.

## Prerequisites
- Docker (version 20.10+)
- Docker Compose (version 1.29+)
- Git

## Services

### PostgreSQL Database
- **Image**: postgres:15-alpine
- **Container Name**: transaction_db
- **Port**: 5432
- **Database**: transaction_platform
- **User**: transaction_user
- **Password**: transaction_password
- **Initial Schema**: Loaded from `Proj_plan/schema.sql`

### Frontend Service
- **Port**: 3000
- **Environment**: Development mode
- **API Endpoint**: http://localhost:8080

## Getting Started

### 1. Configuration
Create a `.env` file from the example:
```bash
cp .env.example .env
```

Modify environment variables as needed.

### 2. Build and Start Services
```bash
# Build images and start services
docker-compose up -d

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f postgres
docker-compose logs -f frontend
```

### 3. Verify Services
```bash
# List running containers
docker-compose ps

# Check PostgreSQL connection
docker-compose exec postgres pg_isready -U transaction_user

# Access PostgreSQL shell
docker-compose exec postgres psql -U transaction_user -d transaction_platform
```

### 4. Frontend Development
The frontend service includes hot-reload for local development:
```bash
# Update frontend Dockerfile and package.json with your code
# Services will automatically reload on file changes
```

### 5. Database Management

#### View Transactions
```bash
docker-compose exec postgres psql -U transaction_user -d transaction_platform
```

Then in the PostgreSQL shell:
```sql
SELECT * FROM transactions;
```

#### Backup Database
```bash
docker-compose exec postgres pg_dump -U transaction_user transaction_platform > backup.sql
```

#### Restore Database
```bash
docker-compose exec postgres psql -U transaction_user -d transaction_platform < backup.sql
```

## Stopping Services
```bash
# Stop all services (keep volumes)
docker-compose stop

# Stop and remove all containers
docker-compose down

# Stop and remove all containers and volumes
docker-compose down -v
```

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL health
docker-compose exec postgres pg_isready -U transaction_user

# Check logs
docker-compose logs postgres
```

### Frontend Not Running
```bash
# Rebuild frontend image
docker-compose up --build frontend

# Check logs
docker-compose logs frontend
```

### Port Already in Use
Modify the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "5433:5432"  # Use 5433 instead of 5432
```

### Clean Rebuild
```bash
# Remove all containers and volumes
docker-compose down -v

# Rebuild and start
docker-compose up -d --build
```

## Development Workflow

1. **Update Frontend Code**: Edit files in `./frontend` directory
2. **Update Database Schema**: Modify `Proj_plan/schema.sql` and restart the database service
3. **Backend Integration**: Uncomment the backend service in `docker-compose.yml` when ready
4. **Environment Customization**: Update `.env` file for different configurations

## Production Considerations

- Change default PostgreSQL credentials in `.env`
- Use stronger passwords
- Enable SSL for database connections
- Set `NODE_ENV=production` for frontend
- Use environment-specific docker-compose files
- Implement proper logging and monitoring
- Set up persistent backup strategies

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
