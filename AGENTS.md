# ERP Frappe / ERPNext — Project Context

## Overview
This directory (`/Users/armando_reyes/ERP_Frappe`) is the root for building a custom **ERP system** powered by the **Frappe Framework** and **ERPNext**.

## Goal
Develop and deploy a tailored ERP solution using Frappe's open-source platform, starting from a clean workspace.

## Tech Stack
- **Framework:** Frappe Framework v16 (Python + JS)
- **ERP Core:** ERPNext v16
- **Database:** MariaDB 11.8
- **Environment:** Local development (macOS) + Docker
- **Node:** v22
- **Python:** 3.14

## Repository
- **GitHub**: https://github.com/LinkingMx/ERP_Frappe
- **Submodule**: `frappe_docker/` → https://github.com/frappe/frappe_docker.git

## Docker Development Environment

### Estructura de bind mounts (código editable)
```
ERP_Frappe/
├── apps/          ← Código fuente Frappe, ERPNext, apps custom (editable en host)
├── sites/         ← Configuración y datos de sitios
├── logs/          ← Logs del sistema
├── config/        ← Configuración de bench
└── frappe_docker/ ← Submodule oficial de Docker
```

### Comandos rápidos (Makefile)
```bash
make setup          # Inicializa todo el entorno
make start          # Inicia todos los servicios
make stop           # Detiene todos los servicios
make shell          # Accede al shell del backend
make bench-start    # Inicia servidor de desarrollo
make build          # Compila assets frontend
make migrate        # Ejecuta migraciones de DB
make status         # Estado de contenedores
make logs           # Logs en tiempo real
```

### Servicios Docker
| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| Frontend (Nginx) | 8080 | Proxy web + assets estáticos |
| Backend (Bench) | 8000 | Servidor Werkzeug de Frappe |
| WebSocket | 9000 | Socket.IO para tiempo real |
| MariaDB | 3306 | Base de datos |
| Redis Cache | - | Caché de aplicación |
| Redis Queue | - | Cola de trabajos |
| Queue Workers | - | Procesamiento en background |
| Scheduler | - | Tareas programadas |

### Acceso
- **URL**: http://localhost:8080
- **Login**: Administrator / admin
- **Sitio**: development.localhost

## MCP Gateway (Docker MCP Toolkit)
- **URL**: `http://localhost:8811/sse`
- **Status**: ✅ Activo con 6 servidores MCP
- **Herramientas disponibles**: Context7, Fetch, Filesystem, GitHub Official, Memory, Sequential Thinking (60 tools total)
- **Documentación**: Ver `MCP_GATEWAY.md` para uso detallado
- **Comando para iniciar**:
  ```bash
  make mcp-restart
  # o manualmente:
  nohup docker mcp gateway run --servers context7,fetch,filesystem,github-official,memory,sequentialthinking --transport sse --port 8811 --log-calls > /tmp/mcp-gateway.log 2>&1 &
  ```

## Conventions
- Follow Frappe's official documentation and bench CLI patterns.
- Use Python 3.10+ and Node.js 18+ as required by Frappe v15+.
- Maintain all custom apps under `apps/` once the bench is initialized.
- Edit code in host (`apps/`, `sites/`) — changes reflect immediately in containers via bind mounts.

## Next Steps
1. ✅ Initialize Frappe Bench in Docker with editable bind mounts.
2. ✅ Install ERPNext app and dependencies.
3. Create/customize DocTypes, Workflows, and Reports as needed.
4. Build custom apps for specific business requirements.
