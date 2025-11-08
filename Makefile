# Metron Docker Management Makefile

.PHONY: help build up down restart logs ps clean test

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help
	@echo "$(BLUE)Metron Docker Management$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Docker Operations

up: ## Start all services
	@echo "$(GREEN)Starting Metron services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Services started!$(NC)"
	@make ps

up-dev: ## Start development services
	@echo "$(GREEN)Starting Metron development services...$(NC)"
	docker-compose -f docker-compose-dev.yml up -d
	@echo "$(GREEN)Development services started!$(NC)"

down: ## Stop all services
	@echo "$(RED)Stopping Metron services...$(NC)"
	docker-compose down

down-clean: ## Stop services and remove volumes
	@echo "$(RED)Stopping services and removing volumes...$(NC)"
	@read -p "This will delete all data. Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
	fi

restart: ## Restart all services
	@echo "$(GREEN)Restarting Metron services...$(NC)"
	docker-compose restart

restart-%: ## Restart specific service (e.g., make restart-kafka)
	@echo "$(GREEN)Restarting $*...$(NC)"
	docker-compose restart $*

build: ## Build all custom images
	@echo "$(GREEN)Building Metron images...$(NC)"
	docker-compose build

build-nocache: ## Build all images without cache
	@echo "$(GREEN)Building Metron images (no cache)...$(NC)"
	docker-compose build --no-cache

pull: ## Pull latest images
	@echo "$(GREEN)Pulling latest images...$(NC)"
	docker-compose pull

##@ Monitoring

ps: ## Show running services
	@docker-compose ps

logs: ## Show logs from all services
	docker-compose logs -f

logs-%: ## Show logs from specific service (e.g., make logs-kafka)
	docker-compose logs -f $*

stats: ## Show resource usage
	docker stats --no-stream $$(docker-compose ps -q)

health: ## Check health of all services
	@echo "$(BLUE)Service Health Status:$(NC)"
	@docker-compose ps | grep -E '(Up|healthy|unhealthy)'

##@ Development

shell-%: ## Open shell in service (e.g., make shell-kafka)
	docker-compose exec $* /bin/bash

kafka-topics: ## List Kafka topics
	docker exec -it metron-kafka kafka-topics --list --bootstrap-server localhost:9092

kafka-create-topic: ## Create Kafka topic (usage: make kafka-create-topic TOPIC=my-topic)
	docker exec -it metron-kafka kafka-topics --create --topic $(TOPIC) --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092

cassandra-shell: ## Open Cassandra CQL shell
	docker exec -it metron-cassandra cqlsh

es-health: ## Check Elasticsearch health
	@curl -s http://localhost:9200/_cluster/health?pretty

es-indices: ## List Elasticsearch indices
	@curl -s http://localhost:9200/_cat/indices?v

flink-jobs: ## List Flink jobs
	docker exec -it metron-flink-jobmanager flink list

##@ Testing

test: ## Run all tests
	@echo "$(GREEN)Running tests...$(NC)"
	docker-compose run --rm metron-rest mvn test

test-integration: ## Run integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	docker-compose up -d kafka cassandra elasticsearch
	@sleep 30
	docker-compose run --rm metron-rest mvn verify -Pintegration-tests

test-e2e: ## Run end-to-end tests
	@echo "$(GREEN)Running E2E tests...$(NC)"
	./scripts/e2e-test.sh

##@ Maintenance

clean: ## Remove stopped containers and dangling images
	@echo "$(GREEN)Cleaning up...$(NC)"
	docker-compose down --remove-orphans
	docker system prune -f

clean-all: ## Remove all Docker resources (containers, images, volumes)
	@echo "$(RED)WARNING: This will remove ALL Docker data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		docker system prune -a -f --volumes; \
	fi

backup: ## Backup all volumes
	@echo "$(GREEN)Backing up volumes...$(NC)"
	./scripts/backup.sh

restore: ## Restore from backup
	@echo "$(GREEN)Restoring from backup...$(NC)"
	./scripts/restore.sh

##@ Access URLs

urls: ## Display service URLs
	@echo "$(BLUE)Metron Service URLs:$(NC)"
	@echo "$(GREEN)Alerts UI:$(NC)           http://localhost:4200"
	@echo "$(GREEN)Config UI:$(NC)           http://localhost:4201"
	@echo "$(GREEN)Kibana:$(NC)              http://localhost:5601"
	@echo "$(GREEN)Superset:$(NC)            http://localhost:8088"
	@echo "$(GREEN)Airflow:$(NC)             http://localhost:8089"
	@echo "$(GREEN)Grafana:$(NC)             http://localhost:3000"
	@echo "$(GREEN)Prometheus:$(NC)          http://localhost:9090"
	@echo "$(GREEN)Flink UI:$(NC)            http://localhost:8082"
	@echo "$(GREEN)MLflow:$(NC)              http://localhost:5000"
	@echo "$(GREEN)Streamlit:$(NC)           http://localhost:8501"
	@echo "$(GREEN)Neo4j:$(NC)               http://localhost:7474"
	@echo "$(GREEN)Jupyter:$(NC)             http://localhost:8888"
	@echo ""
	@echo "$(BLUE)Default Credentials:$(NC)"
	@echo "Superset: admin/admin"
	@echo "Airflow:  admin/admin"
	@echo "Grafana:  admin/admin"
	@echo "Neo4j:    neo4j/metron123"

##@ Quick Actions

quick-start: build up urls ## Build, start, and show URLs

quick-dev: up-dev urls ## Start development environment

status: ps health ## Show status and health

watch: ## Watch service status (refreshes every 5s)
	watch -n 5 'docker-compose ps && echo "" && docker stats --no-stream $$(docker-compose ps -q)'
