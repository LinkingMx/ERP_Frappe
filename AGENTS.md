# ERP Frappe / ERPNext — Project Context

## Overview
This directory (`/Users/armando_reyes/ERP_Frappe`) is the root for building a custom **ERP system** powered by the **Frappe Framework** and **ERPNext**.

## Goal
Develop and deploy a tailored ERP solution using Frappe's open-source platform, starting from a clean workspace.

## Tech Stack
- **Framework:** Frappe Framework (Python + JS)
- **ERP Core:** ERPNext
- **Database:** MariaDB (default for Frappe)
- **Environment:** Local development (macOS)

## Current Status
- **Phase:** Initialization (`init`)
- **Workspace:** Empty directory — ready for scaffold/installation.

## Conventions
- Follow Frappe's official documentation and bench CLI patterns.
- Use Python 3.10+ and Node.js 18+ as required by Frappe v15+.
- Maintain all custom apps under `apps/` once the bench is initialized.

## MCP Gateway (Docker MCP Toolkit)
- **URL**: `http://localhost:8811/sse`
- **Status**: ✅ Activo con 6 servidores MCP
- **Herramientas disponibles**: Context7, Fetch, Filesystem, GitHub Official, Memory, Sequential Thinking (60 tools total)
- **Documentación**: Ver `MCP_GATEWAY.md` para uso detallado
- **Comando para iniciar**:
  ```bash
  nohup docker mcp gateway run --servers context7,fetch,filesystem,github-official,memory,sequentialthinking --transport sse --port 8811 --log-calls > /tmp/mcp-gateway.log 2>&1 &
  ```

## Next Steps
1. Initialize Frappe Bench in this directory.
2. Install ERPNext app and dependencies.
3. Create/customize DocTypes, Workflows, and Reports as needed.
