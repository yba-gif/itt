SHELL := /bin/bash
PY ?= python3.13
DOCKER_BIN_DIR ?= /Applications/Docker.app/Contents/Resources/bin
DOCKER ?= $(shell command -v docker 2>/dev/null || echo $(DOCKER_BIN_DIR)/docker)
# Inject Docker.app's bin dir so docker-credential-desktop is reachable
# even when /usr/local/bin/docker is a stale symlink.
export PATH := $(DOCKER_BIN_DIR):$(PATH)
COMPOSE := $(DOCKER) compose

# ---- Top-level convenience ----

.PHONY: help
help:
	@echo "ITT-Rehber dev targets:"
	@echo "  make up           - bring up Postgres + MinIO + backend + admin (Docker)"
	@echo "  make down         - stop the stack"
	@echo "  make logs         - tail backend logs"
	@echo "  make health       - curl backend healthz"
	@echo "  make test         - run backend smoke tests against the running stack"
	@echo "  make test-unit    - run pure-Python state-machine tests (no DB)"
	@echo "  make venv         - create apps/backend/.venv and install deps"
	@echo "  make admin        - install admin deps + start dev server (no Docker)"
	@echo "  make ios          - regenerate the Xcode project + open it"
	@echo "  make verify       - up + test + health (the Phase 1 acceptance loop)"
	@echo ""
	@echo "Env: PY=python3.13 (override with PY=python3.12 etc)"
	@echo "Env: DOCKER autodetected; falls back to Docker.app's bundled binary"

# ---- Docker stack ----

.PHONY: docker-check
docker-check:
	@if ! [ -x "$(DOCKER)" ]; then \
		echo "Docker not found at $(DOCKER). Open Docker Desktop and try again."; \
		open -a Docker || true; \
		exit 1; \
	fi
	@$(DOCKER) info >/dev/null 2>&1 || { \
		echo "Docker daemon not running. Launching Docker Desktop..."; \
		open -a Docker; \
		echo "Waiting for daemon..."; \
		for i in $$(seq 1 60); do $(DOCKER) info >/dev/null 2>&1 && break; sleep 2; done; \
		$(DOCKER) info >/dev/null 2>&1 || { echo "Docker still not ready. Please start Docker Desktop manually."; exit 1; }; \
	}
	@echo "Docker OK: $$($(DOCKER) version --format '{{.Server.Version}}')"

.PHONY: env
env:
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env from .env.example"; fi

.PHONY: up
up: docker-check env
	$(COMPOSE) up -d
	@echo "Waiting for backend healthz..."
	@for i in $$(seq 1 60); do \
		curl -fsS http://localhost:8000/healthz >/dev/null 2>&1 && { echo; echo "Backend ready."; break; }; \
		printf .; sleep 2; \
	done
	@curl -fsS http://localhost:8000/healthz || { echo; echo "Backend never came up. Try: make logs"; exit 1; }
	@echo
	@echo "Admin:   http://localhost:5173  (login: $${ADMIN_SEED_EMAIL:-bek@itt-rehber.ch} / $${ADMIN_SEED_PASSWORD:-changeme})"
	@echo "API:     http://localhost:8000  (docs at /docs)"
	@echo "MinIO:   http://localhost:9001  (ittminio / ittminio_dev)"

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: logs
logs:
	$(COMPOSE) logs -f backend

.PHONY: health
health:
	@curl -sS http://localhost:8000/healthz | tee /dev/null
	@echo

# ---- Tests ----

.PHONY: venv
venv:
	cd apps/backend && $(PY) -m venv .venv && \
		.venv/bin/pip install -q --upgrade pip && \
		.venv/bin/pip install -q -e ".[dev]"

.PHONY: test-unit
test-unit: venv
	cd apps/backend && .venv/bin/pytest tests/test_state_machine.py tests/test_health.py -q

.PHONY: test
test: venv
	cd apps/backend && \
		DATABASE_URL=postgresql+asyncpg://itt:itt_dev@localhost:5433/itt \
		ADMIN_SEED_EMAIL=bek@itt-rehber.ch \
		ADMIN_SEED_PASSWORD=changeme \
		.venv/bin/pytest -q

.PHONY: verify
verify: up test health
	@echo
	@echo "Phase 1 acceptance loop verified."

# ---- Admin (host-side, no Docker) ----

.PHONY: admin
admin:
	cd apps/admin && npm install && VITE_API_URL=http://localhost:8000 npm run dev

# ---- iOS ----

.PHONY: ios
ios:
	cd apps/ios && xcodegen generate && open ITTRehber.xcodeproj
