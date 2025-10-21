# Multi-Container Architecture Implementation Plan

## Overview

This plan outlines improvements to support multiple ArchivesSpace instances sharing a single Solr container, with flexible per-instance configuration.

---

## Phase 1: Environment-Based Configuration

### 1.1 Create `.env.template` file

**File:** `.env.template`

```bash
# Institution/Instance Identification
INSTANCE_NAME=institution1
CONTAINER_NAME=aspace-institution1

# Port Mappings (must be unique per instance)
FRONTEND_PORT=8080
PUBLIC_PORT=8081

# Database Configuration
DB_HOST=host.docker.internal
DB_PORT=3306
DB_NAME=archivesspace_institution1
DB_USER=as_institution1
DB_PASSWORD=changeme
DB_EXTRA_PARAMS=useUnicode=true&characterEncoding=UTF-8&useSSL=false&allowPublicKeyRetrieval=true

# Solr Configuration (shared Solr instance)
SOLR_HOST=host.docker.internal
SOLR_PORT=8983
SOLR_CORE=institution1
SOLR_VERIFY_CHECKSUMS=false

# Proxy URLs (for public/frontend access)
FRONTEND_PROXY_URL=http://archivesspace.palni.org/institution1
PUBLIC_PROXY_URL=http://archivesspace.palni.org/institution1/public

# Optional: Custom Configuration
# CUSTOM_CONFIG_PATH=./institutions/institution1/config.rb
# CUSTOM_LOCALE_PATH=./institutions/institution1/locales
# CUSTOM_PLUGINS_PATH=./institutions/institution1/plugins

# Volume Names (should be unique per instance)
VOLUME_PREFIX=aspace_institution1
```

### 1.2 Create example instance configurations

**Files to create:**

- `.env.example.institution1` - Example for first institution
- `.env.example.institution2` - Example for second institution
- `.gitignore` update - Add `*.env` except examples

---

## Phase 2: Update Docker Compose for Environment Variables

### 2.1 Modify `docker-compose.yml`

**File:** `docker-compose.yml`

```yaml
version: "3.8"

services:
  aspace:
    container_name: ${CONTAINER_NAME:-aspace}
    build:
      context: .
      args:
        - ASPACE_VERSION=${ASPACE_VERSION:-3.4.1}
    ports:
      - "${FRONTEND_PORT:-8080}:8080"
      - "${PUBLIC_PORT:-8081}:8081"
    environment:
      # Database Configuration
      APPCONFIG_DB_URL: "jdbc:mysql://${DB_HOST:-host.docker.internal}:${DB_PORT:-3306}/${DB_NAME:-archivesspace}?${DB_EXTRA_PARAMS:-useUnicode=true&characterEncoding=UTF-8&useSSL=false&allowPublicKeyRetrieval=true}"

      # Solr Configuration
      APPCONFIG_SOLR_URL: "http://${SOLR_HOST:-host.docker.internal}:${SOLR_PORT:-8983}/solr/${SOLR_CORE:-archivesspace}"
      APPCONFIG_SOLR_VERIFY_CHECKSUMS: "${SOLR_VERIFY_CHECKSUMS:-false}"

      # Proxy URLs
      APPCONFIG_FRONTEND_PROXY_URL: "${FRONTEND_PROXY_URL:-http://localhost:8080}"
      APPCONFIG_PUBLIC_PROXY_URL: "${PUBLIC_PROXY_URL:-http://localhost:8081}"

      # Instance Identification
      INSTANCE_NAME: "${INSTANCE_NAME:-default}"

    restart: unless-stopped
    volumes:
      - ${VOLUME_PREFIX:-aspace}_data:/archivesspace/data
      - ${VOLUME_PREFIX:-aspace}_logs:/archivesspace/logs
      # Optional: Mount custom configurations
      # - ${CUSTOM_CONFIG_PATH:-./configuration/config.rb}:/archivesspace/config/config.rb:ro
      # - ${CUSTOM_LOCALE_PATH:-./configuration/locales}:/archivesspace/locales/custom:ro
      # - ${CUSTOM_PLUGINS_PATH:-./plugins}:/archivesspace/plugins/custom:ro
    networks:
      - aspace-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8089/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

networks:
  aspace-network:
    name: ${NETWORK_NAME:-aspace-shared-network}
    driver: bridge

volumes:
  ${VOLUME_PREFIX:-aspace}_data:
    name: ${VOLUME_PREFIX:-aspace}_data
  ${VOLUME_PREFIX:-aspace}_logs:
    name: ${VOLUME_PREFIX:-aspace}_logs
```

**Note:** Remove the embedded `solr` service since you'll have a shared Solr instance.

---

## Phase 3: Update Dockerfile for Flexibility

### 3.1 Enhance Dockerfile

**File:** `Dockerfile`

Changes to make:

1. Update base image: `FROM ubuntu:22.04` (from 18.04)
2. Add build arguments for version flexibility
3. Remove unused port 8089 from EXPOSE (or keep if needed for healthcheck)
4. Add support for custom config mounting
5. Improve layer caching

```dockerfile
FROM ubuntu:22.04

# Build arguments for flexibility
ARG ASPACE_VERSION=3.4.1
ARG MYSQL_CONNECTOR_VERSION=8.0.28

EXPOSE 8080 8081 8089

# Install dependencies
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get -y install --no-install-recommends \
    build-essential \
    git \
    openjdk-8-jre-headless \
    openjdk-8-jdk \
    ca-certificates \
    wget \
    nano \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download and install ArchivesSpace
RUN wget -q https://github.com/archivesspace/archivesspace/releases/download/v${ASPACE_VERSION}/archivesspace-v${ASPACE_VERSION}.zip && \
    unzip archivesspace-v${ASPACE_VERSION}.zip && \
    rm archivesspace-v${ASPACE_VERSION}.zip

# Download MySQL connector
RUN wget -q https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar && \
    mv mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar /archivesspace/lib/

# Copy default configuration files
COPY ./configuration/en.yml /archivesspace/locales/public/
COPY ./docker-startup.sh /archivesspace/startup.sh

# Set up user and permissions
RUN chmod u+x /archivesspace/startup.sh && \
    groupadd -g 1000 archivesspace && \
    useradd -l -M -u 1000 -g archivesspace archivesspace && \
    chown -R archivesspace:archivesspace /archivesspace

USER archivesspace
WORKDIR /archivesspace

CMD ["./startup.sh"]
```

---

## Phase 4: Create Shared Solr Configuration

### 4.1 Create separate Solr docker-compose

**File:** `docker-compose.solr.yml` (new file)

```yaml
version: "3.8"

services:
  solr:
    image: solr:8.11.1
    container_name: shared-aspace-solr
    ports:
      - "8983:8983"
    volumes:
      - solr_data:/var/solr
      # Mount custom schema if needed
      - ./solr/schema.xml:/opt/solr/server/solr/configsets/_default/conf/schema.xml:ro
      - ./solr/solrconfig.xml:/opt/solr/server/solr/configsets/_default/conf/solrconfig.xml:ro
    networks:
      - aspace-shared-network
    restart: unless-stopped
    healthcheck:
      test:
        ["CMD-SHELL", "curl -f http://localhost:8983/solr/admin/ping || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
    environment:
      - SOLR_HEAP=2g

networks:
  aspace-shared-network:
    name: aspace-shared-network
    driver: bridge

volumes:
  solr_data:
    name: shared_aspace_solr_data
```

### 4.2 Create Solr initialization script

**File:** `scripts/init-solr-core.sh` (new file)

```bash
#!/bin/bash
# Script to create a new Solr core for an ArchivesSpace instance

CORE_NAME=$1

if [ -z "$CORE_NAME" ]; then
    echo "Usage: $0 <core_name>"
    echo "Example: $0 institution1"
    exit 1
fi

echo "Creating Solr core: $CORE_NAME"

docker exec shared-aspace-solr solr create -c "$CORE_NAME" -d _default

echo "Solr core '$CORE_NAME' created successfully"
echo "Update your .env file with: SOLR_CORE=$CORE_NAME"
```

---

## Phase 5: Create Management Scripts

### 5.1 Instance deployment script

**File:** `scripts/deploy-instance.sh` (new file)

```bash
#!/bin/bash
# Deploy a new ArchivesSpace instance

set -e

INSTANCE_NAME=$1
ENV_FILE=".env.${INSTANCE_NAME}"

if [ -z "$INSTANCE_NAME" ]; then
    echo "Usage: $0 <instance_name>"
    echo "Example: $0 institution1"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found"
    echo "Please create it from .env.template"
    exit 1
fi

echo "Deploying instance: $INSTANCE_NAME"

# Load environment variables
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Check if Solr core exists, create if not
echo "Checking Solr core: $SOLR_CORE"
./scripts/init-solr-core.sh "$SOLR_CORE" || true

# Start the container
docker-compose --env-file "$ENV_FILE" up -d

echo "Instance $INSTANCE_NAME deployed successfully"
echo "Frontend: http://localhost:${FRONTEND_PORT}"
echo "Public: http://localhost:${PUBLIC_PORT}"
```

### 5.2 Stop instance script

**File:** `scripts/stop-instance.sh` (new file)

```bash
#!/bin/bash
# Stop a specific ArchivesSpace instance

INSTANCE_NAME=$1
ENV_FILE=".env.${INSTANCE_NAME}"

if [ -z "$INSTANCE_NAME" ]; then
    echo "Usage: $0 <instance_name>"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found"
    exit 1
fi

echo "Stopping instance: $INSTANCE_NAME"

docker-compose --env-file "$ENV_FILE" down

echo "Instance $INSTANCE_NAME stopped"
```

### 5.3 List all instances script

**File:** `scripts/list-instances.sh` (new file)

```bash
#!/bin/bash
# List all running ArchivesSpace instances

echo "Running ArchivesSpace instances:"
echo "================================="

docker ps --filter "name=aspace-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 5.4 Backup instance script

**File:** `scripts/backup-instance.sh` (new file)

```bash
#!/bin/bash
# Backup a specific instance's data

INSTANCE_NAME=$1
BACKUP_DIR="./backups/${INSTANCE_NAME}/$(date +%Y%m%d_%H%M%S)"

if [ -z "$INSTANCE_NAME" ]; then
    echo "Usage: $0 <instance_name>"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "Backing up instance: $INSTANCE_NAME"

# Load environment to get volume names
ENV_FILE=".env.${INSTANCE_NAME}"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

VOLUME_PREFIX=${VOLUME_PREFIX:-aspace_${INSTANCE_NAME}}

# Backup data volume
docker run --rm \
    -v ${VOLUME_PREFIX}_data:/data \
    -v $(pwd)/$BACKUP_DIR:/backup \
    ubuntu tar czf /backup/data.tar.gz -C /data .

# Backup logs volume
docker run --rm \
    -v ${VOLUME_PREFIX}_logs:/logs \
    -v $(pwd)/$BACKUP_DIR:/backup \
    ubuntu tar czf /backup/logs.tar.gz -C /logs .

echo "Backup completed: $BACKUP_DIR"
```

---

## Phase 6: Institution-Specific Configuration

### 6.1 Create institutions directory structure

**Directory structure:**

```
institutions/
├── README.md
├── institution1/
│   ├── config.rb          # Custom config overrides
│   ├── locales/           # Custom locale files
│   └── plugins/           # Custom plugins
├── institution2/
│   ├── config.rb
│   ├── locales/
│   └── plugins/
└── shared/
    └── plugins/           # Plugins used by multiple instances
```

### 6.2 Create institutions README

**File:** `institutions/README.md` (new file)

```markdown
# Institution-Specific Configurations

This directory contains custom configurations for each ArchivesSpace instance.

## Directory Structure

Each institution should have its own subdirectory with:

- `config.rb` - Custom ArchivesSpace configuration
- `locales/` - Custom locale/translation files
- `plugins/` - Institution-specific plugins

## Usage

1. Create a directory for your institution: `mkdir institutions/myinstitution`
2. Add custom configuration files
3. Reference in your `.env` file:
```

CUSTOM_CONFIG_PATH=./institutions/myinstitution/config.rb
CUSTOM_LOCALE_PATH=./institutions/myinstitution/locales
CUSTOM_PLUGINS_PATH=./institutions/myinstitution/plugins

```
4. Uncomment the volume mounts in `docker-compose.yml`

## Shared Resources

The `shared/` directory contains configurations used by multiple instances.
```

---

## Phase 7: Update Documentation

### 7.1 Update README.md

**File:** `README.md`

Add these sections:

````markdown
# PALNI ArchivesSpace Docker - Multi-Instance Setup

## Overview

This repository supports deploying multiple ArchivesSpace instances that share a common Solr instance, each with independent databases and configurations.

## Architecture

- **Shared Solr**: Single Solr container with separate cores per institution
- **Independent Databases**: Each instance connects to its own MySQL database
- **Flexible Configuration**: Per-instance settings via environment files
- **Isolated Data**: Separate Docker volumes for each instance

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed
- MySQL server (can be external or containerized)
- Create databases for each instance (see Database Setup below)

### 2. Set Up Shared Solr

```bash
# Start the shared Solr container
docker-compose -f docker-compose.solr.yml up -d

# Verify Solr is running
curl http://localhost:8983/solr/admin/cores
```
````

### 3. Deploy First Instance

```bash
# Create environment file from template
cp .env.template .env.institution1

# Edit .env.institution1 with your settings:
# - INSTANCE_NAME=institution1
# - CONTAINER_NAME=aspace-institution1
# - FRONTEND_PORT=8080
# - PUBLIC_PORT=8081
# - DB_NAME=archivesspace_institution1
# - SOLR_CORE=institution1

# Deploy the instance
./scripts/deploy-instance.sh institution1
```

### 4. Deploy Additional Instances

```bash
# Create another environment file
cp .env.template .env.institution2

# Edit with different ports and database:
# - FRONTEND_PORT=8082
# - PUBLIC_PORT=8083
# - etc.

# Deploy
./scripts/deploy-instance.sh institution2
```

## Database Setup

For each instance, create a MySQL database:

```sql
CREATE DATABASE archivesspace_institution1 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'as_institution1'@'%' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON archivesspace_institution1.* TO 'as_institution1'@'%';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
```

## Instance Management

### List Running Instances

```bash
./scripts/list-instances.sh
```

### Stop an Instance

```bash
./scripts/stop-instance.sh institution1
```

### Backup an Instance

```bash
./scripts/backup-instance.sh institution1
```

### View Logs

```bash
docker logs aspace-institution1 -f
```

## Custom Configuration

### Per-Instance Customization

1. Create institution directory:

```bash
mkdir -p institutions/myinstitution
```

2. Add custom config:

```bash
cp configuration/config.rb institutions/myinstitution/config.rb
# Edit as needed
```

3. Update `.env` file:

```bash
CUSTOM_CONFIG_PATH=./institutions/myinstitution/config.rb
```

4. Uncomment volume mount in `docker-compose.yml`

## Troubleshooting

### Instance won't start

- Check database connectivity: `docker logs aspace-institution1`
- Verify Solr core exists: `curl http://localhost:8983/solr/admin/cores`
- Check port conflicts: `docker ps`

### Can't connect to Solr

- Ensure Solr container is running: `docker ps | grep solr`
- Verify SOLR_HOST is correct (use `host.docker.internal` for host-based Solr)
- Check Solr core was created: `./scripts/init-solr-core.sh <core_name>`

### Database connection errors

- Verify MySQL is accessible from Docker container
- Check DB credentials in `.env` file
- Ensure database exists and user has permissions

## Tech Stack

- Ubuntu 22.04
- OpenJDK 8
- MySQL 8.0.28
- Apache Solr 8.11.1
- ArchivesSpace 3.4.1

## Resources

- [ArchivesSpace Documentation](https://archivesspace.github.io/tech-docs/)
- [MySQL Setup Guide](https://archivesspace.github.io/tech-docs/provisioning/mysql.html)
- [Docker Hub](https://hub.docker.com/r/pshowell23/aspace-docker)

```

---

## Phase 8: Additional Improvements

### 8.1 Create .gitignore updates
**File:** `.gitignore` (append)

```

# Environment files (keep examples)

.env
.env._
!.env.template
!.env.example._

# Backups

backups/

# Instance-specific configurations (optional - remove if you want to commit these)

# institutions/\*/config.rb

# institutions/_/locales/_

# institutions/_/plugins/_

# Logs

\*.log

# OS files

.DS_Store
Thumbs.db

```

### 8.2 Create Docker ignore file
**File:** `.dockerignore` (update/create)

```

.git/
.gitignore
.env\*
_.md
!README.md
docker-compose_.yml
scripts/
backups/
institutions/
.DS_Store

````

### 8.3 Create example environment files

**File:** `.env.example.institution1`
```bash
INSTANCE_NAME=institution1
CONTAINER_NAME=aspace-institution1
FRONTEND_PORT=8080
PUBLIC_PORT=8081
DB_HOST=host.docker.internal
DB_PORT=3306
DB_NAME=archivesspace_institution1
DB_USER=as_institution1
DB_PASSWORD=CHANGE_ME_PLEASE
DB_EXTRA_PARAMS=useUnicode=true&characterEncoding=UTF-8&useSSL=false&allowPublicKeyRetrieval=true
SOLR_HOST=host.docker.internal
SOLR_PORT=8983
SOLR_CORE=institution1
SOLR_VERIFY_CHECKSUMS=false
FRONTEND_PROXY_URL=http://archivesspace.palni.org/institution1
PUBLIC_PROXY_URL=http://archivesspace.palni.org/institution1/public
VOLUME_PREFIX=aspace_institution1
NETWORK_NAME=aspace-shared-network
````

**File:** `.env.example.institution2`

```bash
INSTANCE_NAME=institution2
CONTAINER_NAME=aspace-institution2
FRONTEND_PORT=8082
PUBLIC_PORT=8083
DB_HOST=host.docker.internal
DB_PORT=3306
DB_NAME=archivesspace_institution2
DB_USER=as_institution2
DB_PASSWORD=CHANGE_ME_PLEASE
DB_EXTRA_PARAMS=useUnicode=true&characterEncoding=UTF-8&useSSL=false&allowPublicKeyRetrieval=true
SOLR_HOST=host.docker.internal
SOLR_PORT=8983
SOLR_CORE=institution2
SOLR_VERIFY_CHECKSUMS=false
FRONTEND_PROXY_URL=http://archivesspace.palni.org/institution2
PUBLIC_PROXY_URL=http://archivesspace.palni.org/institution2/public
VOLUME_PREFIX=aspace_institution2
NETWORK_NAME=aspace-shared-network
```

---

## Implementation Checklist

Use this checklist to track your progress:

- [ ] **Phase 1**: Environment Configuration

  - [ ] Populate `.env.template`
  - [ ] Create `.env.example.institution1`
  - [ ] Create `.env.example.institution2`
  - [ ] Update `.gitignore`

- [ ] **Phase 2**: Docker Compose Updates

  - [ ] Update `docker-compose.yml` with environment variables
  - [ ] Remove embedded Solr service
  - [ ] Add health checks
  - [ ] Add network configuration

- [ ] **Phase 3**: Dockerfile Updates

  - [ ] Update to Ubuntu 22.04
  - [ ] Add build arguments
  - [ ] Add curl for health checks
  - [ ] Improve layer caching

- [ ] **Phase 4**: Shared Solr

  - [ ] Create `docker-compose.solr.yml`
  - [ ] Create `scripts/init-solr-core.sh`
  - [ ] Make script executable (`chmod +x`)
  - [ ] Test Solr deployment

- [ ] **Phase 5**: Management Scripts

  - [ ] Create `scripts/deploy-instance.sh`
  - [ ] Create `scripts/stop-instance.sh`
  - [ ] Create `scripts/list-instances.sh`
  - [ ] Create `scripts/backup-instance.sh`
  - [ ] Make all scripts executable
  - [ ] Test each script

- [ ] **Phase 6**: Institution Configurations

  - [ ] Create `institutions/` directory structure
  - [ ] Create `institutions/README.md`
  - [ ] Set up example institution directories

- [ ] **Phase 7**: Documentation

  - [ ] Update main `README.md`
  - [ ] Add troubleshooting section
  - [ ] Add architecture diagram (optional)
  - [ ] Document backup/restore procedures

- [ ] **Phase 8**: Final Touches
  - [ ] Update `.dockerignore`
  - [ ] Test full deployment workflow
  - [ ] Test with multiple instances
  - [ ] Document any custom configurations

---

## Testing Plan

After implementation, test the following:

1. **Solr Setup**

   ```bash
   docker-compose -f docker-compose.solr.yml up -d
   curl http://localhost:8983/solr/admin/cores
   ```

2. **Single Instance Deployment**

   ```bash
   cp .env.example.institution1 .env.institution1
   # Edit credentials
   ./scripts/deploy-instance.sh institution1
   # Access http://localhost:8080
   ```

3. **Multiple Instances**

   ```bash
   cp .env.example.institution2 .env.institution2
   # Edit credentials
   ./scripts/deploy-instance.sh institution2
   # Access http://localhost:8082
   ```

4. **Instance Management**

   ```bash
   ./scripts/list-instances.sh
   ./scripts/backup-instance.sh institution1
   ./scripts/stop-instance.sh institution1
   ```

5. **Data Persistence**
   - Stop and restart instances
   - Verify data persists
   - Check volume creation: `docker volume ls | grep aspace`

---

## Notes

- Make all scripts executable: `chmod +x scripts/*.sh`
- Replace sensitive data in `.env` files (never commit real passwords)
- Consider using Docker secrets for production
- Set up regular backups with cron jobs
- Monitor resource usage with multiple instances
- Consider implementing a reverse proxy (nginx/traefik) for production
- Document any plugins or custom configurations per institution

---

## Future Enhancements

Consider these additional improvements:

1. **Monitoring**

   - Add Prometheus metrics
   - Set up Grafana dashboards
   - Implement alerting

2. **Automation**

   - CI/CD pipeline for building images
   - Automated backup to S3/cloud storage
   - Automated database migrations

3. **Security**

   - Implement Docker secrets
   - Set up SSL/TLS certificates
   - Add authentication for Solr admin interface
   - Regular security updates

4. **High Availability**

   - Solr clustering
   - Database replication
   - Load balancing for multiple container instances

5. **Developer Experience**
   - Add docker-compose.dev.yml for development
   - Create database seeding scripts
   - Add sample data for testing
