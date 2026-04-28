#!/bin/bash
set -e

# ERP Frappe - Script de inicialización del entorno de desarrollo
# Este script configura Frappe + ERPNext en Docker con volúmenes editables

echo "🚀 Inicializando entorno ERP Frappe..."

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables
FRAPPE_BRANCH="version-16"
ERPNEXT_BRANCH="version-16"
SITE_NAME="development.localhost"
ADMIN_PASSWORD="admin"
DB_ROOT_PASSWORD="123"

# 1. Iniciar servicios de infraestructura
echo -e "${BLUE}📦 Iniciando MariaDB y Redis...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev up -d mariadb redis-cache redis-queue

# Esperar a que MariaDB esté lista
echo -e "${YELLOW}⏳ Esperando a que MariaDB esté lista...${NC}"
until docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T mariadb bash -c "mariadb-admin ping --silent" 2>/dev/null; do
    sleep 2
done
echo -e "${GREEN}✅ MariaDB lista${NC}"

# 2. Iniciar backend
echo -e "${BLUE}🔧 Iniciando backend...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev up -d backend

sleep 3

# 3. Verificar que el contenedor backend está listo
echo -e "${YELLOW}⏳ Verificando backend...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T backend bash -c "whoami && python3 --version"

# 4. Clonar Frappe y ERPNext (dentro del contenedor, se refleja en host)
echo -e "${BLUE}📥 Clonando Frappe Framework y ERPNext...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T backend bash -c "
  cd /workspace
  
  if [ ! -d 'apps/frappe' ]; then
    echo 'Clonando Frappe...'
    git clone https://github.com/frappe/frappe.git --branch $FRAPPE_BRANCH --depth 1 apps/frappe
  else
    echo 'Frappe ya existe'
  fi
  
  if [ ! -d 'apps/erpnext' ]; then
    echo 'Clonando ERPNext...'
    git clone https://github.com/frappe/erpnext.git --branch $ERPNEXT_BRANCH --depth 1 apps/erpnext
  else
    echo 'ERPNext ya existe'
  fi
"

# 5. Inicializar bench
echo -e "${BLUE}⚙️  Inicializando bench...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T backend bash -c "
  cd /workspace
  
  # Crear directorio de desarrollo
  mkdir -p development
  cd development
  
  # Inicializar bench si no existe
  if [ ! -d 'frappe-bench' ]; then
    echo 'Inicializando frappe-bench...'
    bench init --skip-redis-config-generation --frappe-branch $FRAPPE_BRANCH frappe-bench
  fi
  
  cd frappe-bench
  
  # Configurar conexiones
  bench set-config -g db_host mariadb
  bench set-config -gp db_port 3306
  bench set-config -g redis_cache 'redis://redis-cache:6379'
  bench set-config -g redis_queue 'redis://redis-queue:6379'
  bench set-config -g redis_socketio 'redis://redis-queue:6379'
  
  # Asegurar que sites/apps.txt tenga ambas apps
  printf 'frappe\nerpnext\n' > sites/apps.txt
  
  # Crear symlinks a los repos clonados (para edición en host)
  echo 'Configurando symlinks a apps...'
  rm -rf apps/frappe apps/erpnext 2>/dev/null || true
  ln -s /workspace/apps/frappe apps/frappe
  ln -s /workspace/apps/erpnext apps/erpnext
  
  # Instalar dependencias Python
  echo 'Instalando dependencias Python...'
  source env/bin/activate
  pip install -e apps/frappe --quiet 2>&1 | tail -3
  pip install -e apps/erpnext --quiet 2>&1 | tail -3
  
  # Instalar dependencias Node
  echo 'Instalando dependencias Node...'
  cd apps/frappe && yarn install --silent && cd ../..
"

# 6. Crear sitio e instalar ERPNext
echo -e "${BLUE}🌐 Creando sitio $SITE_NAME...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T backend bash -c "
  cd /workspace/development/frappe-bench
  source env/bin/activate
  
  # Crear sitio si no existe
  if [ ! -d 'sites/$SITE_NAME' ]; then
    echo 'Creando sitio...'
    bench new-site --mariadb-user-host-login-scope=% \
      --db-root-password $DB_ROOT_PASSWORD \
      --admin-password $ADMIN_PASSWORD \
      $SITE_NAME
  else
    echo 'Sitio ya existe'
  fi
  
  # Instalar ERPNext
  echo 'Instalando ERPNext en el sitio...'
  bench --site $SITE_NAME install-app erpnext
  
  # Habilitar modo desarrollador
  bench --site $SITE_NAME set-config developer_mode 1
  bench --site $SITE_NAME clear-cache
"

echo ""
echo -e "${GREEN}✅ Entorno inicializado correctamente!${NC}"
echo ""
echo -e "${BLUE}📋 Comandos útiles:${NC}"
echo "  Iniciar servidor:  make bench-start"
echo "  Acceder al shell:  make shell"
echo "  Ver logs:          make logs"
echo ""
echo -e "${BLUE}🌐 Acceso:${NC}"
echo "  URL:      http://localhost:8000"
echo "  Login:    Administrator / $ADMIN_PASSWORD"
echo "  Sitio:    $SITE_NAME"
echo ""
echo -e "${BLUE}📁 Estructura (editable en host):${NC}"
echo "  apps/frappe/   - Código fuente Frappe Framework"
echo "  apps/erpnext/  - Código fuente ERPNext"
echo "  development/frappe-bench/sites/  - Sitios y configuración"
echo ""
