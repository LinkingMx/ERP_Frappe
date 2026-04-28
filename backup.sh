#!/bin/bash
# ERP Frappe - Script de backup completo (MariaDB incremental + Restic)
# Uso: ./backup.sh [full|inc|files|all|restore|status]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BACKUP_TYPE=${1:-auto}
DB_PASSWORD=${DB_PASSWORD:-123}
RESTIC_PASSWORD=${RESTIC_PASSWORD:-erpnext_backup_2025}

# Detectar si es domingo (día de full backup)
DAY_OF_WEEK=$(date +%u)
IS_SUNDAY=$([ "$DAY_OF_WEEK" = "7" ] && echo "1" || echo "0")

echo "🚀 ERP Frappe Backup System"
echo "=========================="
echo "Fecha: $(date)"
echo "Tipo solicitado: $BACKUP_TYPE"
echo "Día de la semana: $DAY_OF_WEEK (Domingo=$IS_SUNDAY)"
echo ""

case "$BACKUP_TYPE" in
  full|FULL)
    echo -e "${BLUE}🗄️  Ejecutando MariaDB FULL Backup...${NC}"
    docker compose -f docker-compose.backup.yml run --rm mariadb-backup-full
    ;;

  inc|INC|incremental)
    echo -e "${BLUE}🗄️  Ejecutando MariaDB INCREMENTAL Backup...${NC}"
    docker compose -f docker-compose.backup.yml run --rm mariadb-backup-inc
    ;;

  files|FILES)
    echo -e "${BLUE}📁 Ejecutando Restic Backup (archivos)...${NC}"
    
    # Verificar si el repo existe, si no, inicializarlo
    if [ ! -f "backups/restic-repo/config" ]; then
      echo -e "${YELLOW}⚠️  Inicializando repositorio Restic...${NC}"
      docker compose -f docker-compose.backup.yml run --rm restic-init
    fi
    
    docker compose -f docker-compose.backup.yml run --rm restic-backup
    ;;

  all|ALL|auto)
    # Decidir si es full o incremental
    if [ "$IS_SUNDAY" = "1" ] || [ "$BACKUP_TYPE" = "full" ] || [ "$BACKUP_TYPE" = "ALL" ]; then
      echo -e "${BLUE}🗄️  [1/4] MariaDB FULL Backup${NC}"
      docker compose -f docker-compose.backup.yml run --rm mariadb-backup-full
    else
      echo -e "${BLUE}🗄️  [1/4] MariaDB INCREMENTAL Backup${NC}"
      docker compose -f docker-compose.backup.yml run --rm mariadb-backup-inc
    fi
    
    echo ""
    echo -e "${BLUE}📁 [2/4] Restic Backup (archivos)${NC}"
    if [ ! -f "backups/restic-repo/config" ]; then
      echo -e "${YELLOW}⚠️  Inicializando repositorio Restic...${NC}"
      docker compose -f docker-compose.backup.yml run --rm restic-init
    fi
    docker compose -f docker-compose.backup.yml run --rm restic-backup
    
    echo ""
    echo -e "${BLUE}🧹 [3/4] Rotación de backups antiguos${NC}"
    docker compose -f docker-compose.backup.yml run --rm restic-forget
    
    echo ""
    echo -e "${BLUE}📊 [4/4] Resumen de backups${NC}"
    echo "--- MariaDB Backups ---"
    ls -1td backups/mariadb-full/* 2>/dev/null | head -3 | while read dir; do
      echo "  FULL: $(basename $dir) ($(du -sh "$dir" | cut -f1))"
    done
    ls -1td backups/mariadb-inc/* 2>/dev/null | head -3 | while read dir; do
      echo "  INC:  $(basename $dir) ($(du -sh "$dir" | cut -f1))"
    done
    
    echo ""
    echo "--- Restic Snapshots ---"
    docker compose -f docker-compose.backup.yml run --rm restic-snapshots
    
    echo ""
    echo -e "${GREEN}✅ Backup completado exitosamente${NC}"
    ;;

  restore|RESTORE)
    echo -e "${YELLOW}🔄 Opciones de restauración:${NC}"
    echo ""
    echo "1. Restaurar MariaDB desde backup FULL:"
    echo "   docker compose -f docker-compose.backup.yml run --rm mariadb-restore"
    echo ""
    echo "2. Restaurar archivos desde Restic:"
    echo "   docker compose -f docker-compose.backup.yml run --rm restic-restore"
    echo ""
    echo "3. Ver snapshots disponibles:"
    echo "   docker compose -f docker-compose.backup.yml run --rm restic-snapshots"
    echo ""
    ;;

  status|STATUS)
    echo -e "${BLUE}📊 Estado del sistema de backups${NC}"
    echo "================================"
    
    echo ""
    echo "--- MariaDB Full Backups ---"
    if [ -d "backups/mariadb-full" ] && [ "$(ls -A backups/mariadb-full 2>/dev/null)" ]; then
      ls -1td backups/mariadb-full/* 2>/dev/null | while read dir; do
        echo "  📦 $(basename $dir) → $(du -sh "$dir" | cut -f1)"
      done
    else
      echo "  ❌ No hay backups FULL"
    fi
    
    echo ""
    echo "--- MariaDB Incremental Backups ---"
    if [ -d "backups/mariadb-inc" ] && [ "$(ls -A backups/mariadb-inc 2>/dev/null)" ]; then
      ls -1td backups/mariadb-inc/* 2>/dev/null | while read dir; do
        echo "  📦 $(basename $dir) → $(du -sh "$dir" | cut -f1)"
      done
    else
      echo "  ❌ No hay backups incrementales"
    fi
    
    echo ""
    echo "--- Restic Repository ---"
    if [ -f "backups/restic-repo/config" ]; then
      docker compose -f docker-compose.backup.yml run --rm restic-snapshots 2>/dev/null || echo "  ⚠️  No se pudieron listar snapshots"
    else
      echo "  ❌ Repositorio Restic no inicializado"
    fi
    
    echo ""
    echo "--- Espacio utilizado ---"
    du -sh backups/ 2>/dev/null || echo "  📂 Directorio backups/ vacío"
    ;;

  *)
    echo "Uso: $0 [full|inc|files|all|restore|status]"
    echo ""
    echo "  full     → Backup FULL de MariaDB (todos los datos)"
    echo "  inc      → Backup INCREMENTAL de MariaDB (solo cambios)"
    echo "  files    → Backup de archivos con Restic (deduplicación)"
    echo "  all      → Ejecuta todo (full los domingos, inc otros días)"
    echo "  restore  → Muestra opciones de restauración"
    echo "  status   → Muestra estado de todos los backups"
    echo ""
    echo "Ejemplos:"
    echo "  $0 full      # Forzar backup full"
    echo "  $0 all       # Backup automático (decide full/inc)"
    echo "  $0 status    # Ver estado"
    exit 1
    ;;
esac
