# MCP Gateway — Docker MCP Toolkit

## Estado
✅ **Gateway activo y corriendo** en `http://localhost:8811/sse`

## Configuración

### Iniciar Gateway
```bash
# Forma manual (desarrollo)
nohup docker mcp gateway run \
  --servers context7,fetch,filesystem,github-official,memory,sequentialthinking \
  --transport sse \
  --port 8811 \
  --log-calls > /tmp/mcp-gateway.log 2>&1 &
```

### Verificar estado
```bash
ps aux | grep "mcp gateway" | grep -v grep
tail -f /tmp/mcp-gateway.log
```

## Servidores MCP Habilitados (6)

| Servidor | Herramientas | Descripción |
|----------|-------------|-------------|
| **context7** | 2 | Documentación actualizada de código (resolve-library-id, get-library-docs) |
| **fetch** | 1 | Obtener contenido de URLs como markdown |
| **filesystem** | ~11 | Acceso al sistema de archivos local |
| **github-official** | 41 + 2 prompts + 5 templates | Operaciones GitHub oficiales |
| **memory** | 9 | Grafo de conocimiento persistente |
| **sequentialthinking** | 1 | Pensamiento secuencial dinámico |

**Total: 60 herramientas disponibles**

## Uso de Herramientas MCP

### Formato de llamada
```bash
docker mcp tools call <tool-name> <arg1>=<value1> <arg2>=<value2> ...
```

### Ejemplos

#### Context7 — Buscar documentación de una librería
```bash
docker mcp tools call resolve-library-id libraryName="Frappe Framework"
```

#### Context7 — Obtener documentación específica
```bash
docker mcp tools call get-library-docs \
  context7CompatibleLibraryID="/websites/frappe_io_framework" \
  tokens=5000 \
  topic="installation"
```

#### Fetch — Obtener contenido de una URL
```bash
docker mcp tools call fetch url="https://docs.frappe.io/framework/user/en/installation"
```

#### GitHub — Listar repositorios
```bash
docker mcp tools call list_user_repositories type="owner" sort="updated"
```

#### Memory — Crear entidad en el grafo de conocimiento
```bash
docker mcp tools call create_entities \
  entities='[{"name":"ERP Frappe","entityType":"project","observations":["Proyecto ERP con Frappe Framework"]}]'
```

## Librerías Context7 Relevantes para este Proyecto

| Librería | ID | Trust Score | Snippets |
|----------|-----|-------------|----------|
| Frappe Framework (docs) | `/websites/frappe_io_framework` | 10 | 1,289 |
| Frappe Framework (user) | `/websites/frappe_io_framework_user_en` | 10 | 1,275 |
| Frappe (GitHub) | `/frappe/frappe` | 8.5 | 901 |
| Frappe Documentation | `/websites/frappe_io` | 10 | 5,577 |
| Frappe Docker | `/frappe/frappe_docker` | 8.5 | 533 |
| Frappe UI | `/frappe/frappe-ui` | 8.5 | 273 |
| Frappe HR | `/frappe/hrms` | 8.5 | 117 |
| ERPNext | disponible vía búsqueda | - | - |

## Notas
- **Token de autorización**: Se genera automáticamente al iniciar el gateway
- **Filesystem**: Requiere configurar paths en `~/.docker/mcp/config.yaml`
- **GitHub**: Requiere `GITHUB_PERSONAL_ACCESS_TOKEN` configurado
- **Logs**: Disponibles en `/tmp/mcp-gateway.log`
