# ERP Frappe - Makefile de comandos comunes

COMPOSE_FILE := docker-compose.dev.yml
ENV_FILE := .env.dev
COMPOSE := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)
BENCH_PATH := /workspace/development/frappe-bench
SITE_NAME := development.localhost

.PHONY: help setup start stop restart logs shell bench-start build migrate status

help: ## Muestra esta ayuda
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Inicializa el entorno completo (MariaDB, Redis, Frappe, ERPNext)
	./setup.sh

start: ## Inicia todos los servicios
	$(COMPOSE) up -d

stop: ## Detiene todos los servicios
	$(COMPOSE) down

restart: ## Reinicia todos los servicios
	$(COMPOSE) restart

logs: ## Muestra logs en tiempo real
	$(COMPOSE) logs -f

shell: ## Accede al shell del backend como usuario frappe
	$(COMPOSE) exec backend bash

bench-start: ## Inicia el servidor de desarrollo de bench
	$(COMPOSE) exec backend bash -c "cd $(BENCH_PATH) && bench start"

bench-migrate: ## Ejecuta migraciones de base de datos
	$(COMPOSE) exec backend bash -c "cd $(BENCH_PATH) && bench --site $(SITE_NAME) migrate"

bench-build: ## Compila assets frontend
	$(COMPOSE) exec backend bash -c "cd $(BENCH_PATH) && bench build"

bench-console: ## Abre consola Python de Frappe
	$(COMPOSE) exec backend bash -c "cd $(BENCH_PATH) && bench --site $(SITE_NAME) console"

new-app: ## Crea una nueva app Frappe (usar: make new-app NAME=mi_app)
	$(COMPOSE) exec backend bash -c "cd $(BENCH_PATH) && bench new-app $(NAME)"

install-app: ## Instala una app en el sitio (usar: make install-app NAME=mi_app)
	$(COMPOSE) exec backend bash -c "cd $(BENCH_PATH) && bench --site $(SITE_NAME) install-app $(NAME)"

status: ## Muestra estado de los contenedores
	$(COMPOSE) ps

mcp-status: ## Verifica estado del MCP Gateway
	@echo "MCP Gateway PID: $$(cat /tmp/mcp-gateway.pid 2>/dev/null || echo 'no encontrado')"
	@ps aux | grep "mcp gateway" | grep -v grep || echo "Gateway no está corriendo"

mcp-restart: ## Reinicia el MCP Gateway
	-pkill -f "docker mcp gateway run" 2>/dev/null
	@sleep 2
	@nohup docker mcp gateway run --servers context7,fetch,filesystem,github-official,memory,sequentialthinking --transport sse --port 8811 --log-calls > /tmp/mcp-gateway.log 2>&1 &
	@echo $$! > /tmp/mcp-gateway.pid
	@echo "MCP Gateway reiniciado en http://localhost:8811/sse"

mcp-tools: ## Lista herramientas MCP disponibles
	@docker mcp tools ls

gh-push: ## Hace push de cambios a GitHub
	git add -A
	git commit -m "update: cambios locales $$(date +%Y-%m-%d_%H:%M)" || true
	git push origin main

clean: ## Limpia volúmenes y contenedores (¡cuidado!)
	$(COMPOSE) down -v
	@docker volume rm -f erp_frappe_mariadb-data 2>/dev/null || true
	@rm -rf development/
