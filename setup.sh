#!/bin/bash
set -e

# ERP Frappe - Script de inicialización del entorno de desarrollo
# Este script configura Frappe + ERPNext en Docker con volúmenes editables

echo "🚀 Inicializando entorno ERP Frappe..."

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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
until docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T mariadb mysqladmin ping --silent; do
    sleep 2
done
echo -e "${GREEN}✅ MariaDB lista${NC}"

# 2. Clonar Frappe y ERPNext
echo -e "${BLUE}📥 Clonando Frappe Framework...${NC}"
if [ ! -d "apps/frappe" ]; then
    git clone https://github.com/frappe/frappe.git --branch $FRAPPE_BRANCH --depth 1 apps/frappe
else
    echo -e "${YELLOW}⚠️  Frappe ya existe, omitiendo...${NC}"
fi

echo -e "${BLUE}📥 Clonando ERPNext...${NC}"
if [ ! -d "apps/erpnext" ]; then
    git clone https://github.com/frappe/erpnext.git --branch $ERPNEXT_BRANCH --depth 1 apps/erpnext
else
    echo -e "${YELLOW}⚠️  ERPNext ya existe, omitiendo...${NC}"
fi

# 3. Iniciar backend
echo -e "${BLUE}🔧 Iniciando backend...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev up -d backend

# Esperar a que el backend esté listo
echo -e "${YELLOW}⏳ Esperando a que el backend esté listo...${NC}"
sleep 5

# 4. Inicializar bench dentro del contenedor
echo -e "${BLUE}⚙️  Inicializando bench...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T backend bash -c "
    cd /home/frappe/frappe-bench
    
    # Instalar Frappe
    if [ ! -d 'env' ] || [ ! -f 'env/bin/python' ]; then
        echo 'Creando entorno virtual...'
        python3 -m venv env
    fi
    
    source env/bin/activate
    
    # Instalar dependencias de Frappe
    echo 'Instalando dependencias de Frappe...'
    pip install -e apps/frappe --quiet
    
    # Instalar ERPNext
    echo 'Instalando ERPNext...'
    pip install -e apps/erpnext --quiet
    
    # Instalar Node dependencies
    echo 'Instalando dependencias Node...'
    cd apps/frappe && yarn install --silent && cd ../..
    
    # Configurar bench
    echo 'Configurando bench...'
    bench set-config -g db_host mariadb
    bench set-config -gp db_port 3306
    bench set-config -g redis_cache 'redis://redis-cache:6379'
    bench set-config -g redis_queue 'redis://redis-queue:6379'
    bench set-config -g redis_socketio 'redis://redis-queue:6379'
"

# 5. Crear sitio
echo -e "${BLUE}🌐 Creando sitio $SITE_NAME...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T backend bash -c "
    cd /home/frappe/frappe-bench
    source env/bin/activate
    
    if [ ! -d 'sites/$SITE_NAME' ]; then
        bench new-site --mariadb-user-host-login-scope=% \
            --db-root-password $DB_ROOT_PASSWORD \
            --admin-password $ADMIN_PASSWORD \
            $SITE_NAME
    else
        echo 'Sitio ya existe, omitiendo...'
    fi
    
    # Instalar ERPNext en el sitio
    bench --site $SITE_NAME install-app erpnext
    
    # Habilitar modo desarrollador
    bench --site $SITE_NAME set-config developer_mode 1
    bench --site $SITE_NAME clear-cache
"

# 6. Iniciar servicios restantes
echo -e "${BLUE}🚀 Iniciando servicios restantes...${NC}"
docker compose -f docker-compose.dev.yml --env-file .env.dev up -d frontend websocket queue-short queue-long scheduler

echo ""
echo -e "${GREEN}✅ Entorno inicializado correctamente!${NC}"
echo ""
echo -e "${BLUE}📋 Comandos útiles:${NC}"
echo "  Iniciar servidor de desarrollo:  docker compose -f docker-compose.dev.yml exec backend bash -c 'cd /home/frappe/frappe-bench && bench start'"
echo "  Acceder al contenedor backend:   docker compose -f docker-compose.dev.yml exec backend bash"
echo "  Ver logs:                        docker compose -f docker-compose.dev.yml logs -f"
echo "  Acceder a la app:                http://localhost:8080"
echo "  Login:                           Administrator / $ADMIN_PASSWORD"
echo ""
echo -e "${BLUE}📁 Estructura de directorios:${NC}"
echo "  apps/     - Código fuente de Frappe, ERPNext y apps personalizadas"
echo "  sites/    - Configuración y datos de sitios"
echo "  logs/     - Logs del sistema"
echo ""
