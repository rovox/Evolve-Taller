.PHONY: start stop stop-with-volumes status logs logs-da logs-sequencer logs-extras start-extras stop-extras clean help

# Colores para mensajes
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
RED := $(shell tput setaf 1)
RESET := $(shell tput sgr0)

help:
	@echo "$(GREEN)EV-Stack Deployment Commands:$(RESET)"
	@echo "$(YELLOW)Core Services:$(RESET)"
	@echo "  make start              - Inicia los servicios core (da-celestia, sequencer)"
	@echo "  make stop               - Detiene todos los servicios core"
	@echo "  make stop-with-volumes  - Detiene servicios core y elimina volúmenes"
	@echo "  make status             - Muestra el estado de todos los servicios"
	@echo "$(YELLOW)Logs:$(RESET)"
	@echo "  make logs               - Muestra logs de todos los servicios core"
	@echo "  make logs-da            - Muestra logs de Celestia DA"
	@echo "  make logs-sequencer     - Muestra logs del Sequencer"
	@echo "  make logs-extras        - Muestra logs de servicios extras"
	@echo "$(YELLOW)Servicios Extra:$(RESET)"
	@echo "  make start-extras       - Inicia servicios extras (explorer, faucet)"
	@echo "  make stop-extras        - Detiene servicios extras"
	@echo "$(YELLOW)Mantenimiento:$(RESET)"
	@echo "  make clean              - Limpia volúmenes y redes"

# Iniciar servicios core en orden con health checks
start:
	@echo "$(GREEN)🚀 Iniciando servicios core...$(RESET)"
	@echo "$(YELLOW)Step 1/2: Iniciando Celestia DA...$(RESET)"
	@cd stacks/da-celestia && docker compose up -d
	@echo "$(YELLOW)⏳ Esperando a que Celestia DA esté listo...$(RESET)"
	@timeout=120; elapsed=0; \
	while ! curl -s http://localhost:26658 >/dev/null 2>&1; do \
		if [ $$elapsed -ge $$timeout ]; then \
			echo "$(RED)❌ Error: Celestia DA no respondió en $$timeout segundos$(RESET)"; \
			exit 1; \
		fi; \
		sleep 5; \
		elapsed=$$((elapsed + 5)); \
		echo "$(YELLOW)  Esperando... ($$elapsed/$$timeout s)$(RESET)"; \
	done
	@echo "$(GREEN)✅ Celestia DA está listo$(RESET)"
	@echo "$(YELLOW)Step 2/2: Iniciando Sequencer...$(RESET)"
	@cd stacks/single-sequencer && docker compose up -d
	@echo "$(YELLOW)⏳ Esperando a que el Sequencer esté listo...$(RESET)"
	@timeout=120; elapsed=0; \
	while ! curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
		http://localhost:8545 >/dev/null 2>&1; do \
		if [ $$elapsed -ge $$timeout ]; then \
			echo "$(RED)❌ Error: Sequencer no respondió en $$timeout segundos$(RESET)"; \
			exit 1; \
		fi; \
		sleep 5; \
		elapsed=$$((elapsed + 5)); \
		echo "$(YELLOW)  Esperando... ($$elapsed/$$timeout s)$(RESET)"; \
	done
	@echo "$(GREEN)✅ Sequencer está listo$(RESET)"
	@echo "$(GREEN)✅ Servicios core iniciados$(RESET)"
	@echo "$(YELLOW)Endpoints:$(RESET)"
	@echo "• Celestia DA: http://localhost:26658"
	@echo "• Sequencer:   http://localhost:8545"

# Detener servicios core en orden inverso
stop:
	@echo "$(YELLOW)🛑 Deteniendo servicios core...$(RESET)"
	@if [ -d "stacks/single-sequencer" ]; then \
		cd stacks/single-sequencer && docker compose down; \
	fi
	@if [ -d "stacks/da-celestia" ]; then \
		cd stacks/da-celestia && docker compose down; \
	fi
	@echo "$(GREEN)✅ Servicios core detenidos$(RESET)"

# Detener servicios core con limpieza de volúmenes
stop-with-volumes:
	@echo "$(YELLOW)🛑 Deteniendo servicios core y eliminando volúmenes...$(RESET)"
	@if [ -d "stacks/single-sequencer" ]; then \
		cd stacks/single-sequencer && docker compose down -v; \
	fi
	@if [ -d "stacks/da-celestia" ]; then \
		cd stacks/da-celestia && docker compose down -v; \
	fi
	@echo "$(GREEN)✅ Servicios core detenidos y volúmenes eliminados$(RESET)"

# Mostrar estado de todos los servicios
status:
	@echo "$(YELLOW)📊 Estado de Celestia DA:$(RESET)"
	@if [ -d "stacks/da-celestia" ]; then \
		cd stacks/da-celestia && docker compose ps; \
	else \
		echo "$(RED)Stack da-celestia no encontrado$(RESET)"; \
	fi
	@echo "\n$(YELLOW)📊 Estado del Sequencer:$(RESET)"
	@if [ -d "stacks/single-sequencer" ]; then \
		cd stacks/single-sequencer && docker compose ps; \
	else \
		echo "$(RED)Stack single-sequencer no encontrado$(RESET)"; \
	fi
	@echo "\n$(YELLOW)📊 Estado de servicios extras:$(RESET)"
	@if [ -d "stacks/eth-faucet" ]; then \
		cd stacks/eth-faucet && docker compose ps 2>/dev/null || echo "Faucet: no iniciado"; \
	fi
	@if [ -d "stacks/eth-explorer" ]; then \
		cd stacks/eth-explorer && docker compose ps 2>/dev/null || echo "Explorer: no iniciado"; \
	fi

# Comandos para ver logs
logs:
	@echo "$(YELLOW)📜 Mostrando logs de servicios core...$(RESET)"
	@cd stacks/da-celestia && docker compose logs -f

logs-da:
	@echo "$(YELLOW)📜 Logs de Celestia DA:$(RESET)"
	@cd stacks/da-celestia && docker compose logs -f

logs-sequencer:
	@echo "$(YELLOW)📜 Logs del Sequencer:$(RESET)"
	@cd stacks/single-sequencer && docker compose logs -f

logs-extras:
	@echo "$(YELLOW)📜 Logs de servicios extras:$(RESET)"
	@echo "$(YELLOW)Faucet:$(RESET)"
	@if [ -d "stacks/eth-faucet" ]; then \
		cd stacks/eth-faucet && docker compose logs --tail=50; \
	fi
	@echo "\n$(YELLOW)Explorer:$(RESET)"
	@if [ -d "stacks/eth-explorer" ]; then \
		cd stacks/eth-explorer && docker compose logs --tail=50; \
	fi

# Servicios extras (requiere sequencer activo)
start-extras:
	@echo "$(GREEN)🚀 Iniciando servicios extras...$(RESET)"
	@echo "$(YELLOW)Verificando que el Sequencer esté activo...$(RESET)"
	@if ! curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
		http://localhost:8545 >/dev/null 2>&1; then \
		echo "$(RED)❌ Error: Sequencer no está activo. Ejecuta 'make start' primero.$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Sequencer activo$(RESET)"
	@if [ -d "stacks/eth-faucet" ]; then \
		echo "$(YELLOW)Iniciando Faucet...$(RESET)"; \
		cd stacks/eth-faucet && docker compose up -d; \
	fi
	@if [ -d "stacks/eth-explorer" ]; then \
		echo "$(YELLOW)Iniciando Explorer...$(RESET)"; \
		cd stacks/eth-explorer && docker compose up -d; \
	fi
	@echo "$(GREEN)✅ Servicios extras iniciados$(RESET)"
	@echo "$(YELLOW)Endpoints adicionales:$(RESET)"
	@echo "• Faucet:   http://localhost:8081"
	@echo "• Explorer: http://localhost:3000"

stop-extras:
	@echo "$(YELLOW)🛑 Deteniendo servicios extras...$(RESET)"
	@if [ -d "stacks/eth-explorer" ]; then \
		cd stacks/eth-explorer && docker compose down; \
	fi
	@if [ -d "stacks/eth-faucet" ]; then \
		cd stacks/eth-faucet && docker compose down; \
	fi
	@echo "$(GREEN)✅ Servicios extras detenidos$(RESET)"

# Limpieza completa
clean:
	@echo "$(YELLOW)🧹 Limpiando volúmenes y redes...$(RESET)"
	@docker volume rm celestia-appd-data celestia-node-data \
		da-celestia_celestia-appd-data \
		single-sequencer_jwttoken-sequencer \
		single-sequencer_ev-reth-sequencer-data \
		single-sequencer_sequencer-data \
		single-sequencer_sequencer-export \
		eth-explorer_pg-data \
		eth-explorer_pg-stats-data \
		eth-explorer_redis-data \
		2>/dev/null || true
	@docker network prune -f
	@echo "$(GREEN)✅ Limpieza completada$(RESET)"