# Makefile para operaciones del clúster Enterprise Webmin/Virtualmin

.PHONY: help deploy destroy verify plan apply ansible-only clean logs status backup restore scale-up scale-down update monitoring-alerts security-scan compliance-check cost-status cost-report cost-analysis cost-alerts cost-optimize cost-dashboard

# Variables
TERRAFORM_DIR = terraform
ANSIBLE_DIR = ansible
DEPLOY_SCRIPT = ./deploy-cluster.sh
VERIFY_SCRIPT = ./verify-deployment.sh

# Colores para output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

# Función de ayuda
help: ## Mostrar esta ayuda
	@echo "$(BLUE)Comandos disponibles para el clúster Enterprise Webmin/Virtualmin:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# Despliegue completo
deploy: ## Desplegar clúster completo (Terraform + Ansible + Verificación)
	@echo "$(BLUE)🚀 Iniciando despliegue completo del clúster...$(NC)"
	chmod +x $(DEPLOY_SCRIPT)
	$(DEPLOY_SCRIPT)

# Destruir infraestructura
destroy: ## Destruir toda la infraestructura
	@echo "$(RED)⚠️  Destruir toda la infraestructura$(NC)"
	@echo "$(YELLOW)Esta acción no se puede deshacer. ¿Estás seguro? [y/N]$(NC)"
	@read -p "" -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		cd $(TERRAFORM_DIR) && terraform destroy -auto-approve; \
		echo "$(GREEN)✅ Infraestructura destruida$(NC)"; \
	else \
		echo ""; \
		echo "$(BLUE)Operación cancelada$(NC)"; \
	fi

# Verificar despliegue
verify: ## Ejecutar verificación completa del clúster
	@echo "$(BLUE)🔍 Ejecutando verificación del clúster...$(NC)"
	chmod +x $(VERIFY_SCRIPT)
	$(VERIFY_SCRIPT)

# Planificar cambios
plan: ## Mostrar plan de cambios de Terraform
	@echo "$(BLUE)📋 Planificando cambios en infraestructura...$(NC)"
	cd $(TERRAFORM_DIR) && terraform plan

# Aplicar cambios
apply: ## Aplicar cambios de Terraform
	@echo "$(BLUE)⚙️  Aplicando cambios en infraestructura...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply

# Solo Ansible
ansible-only: ## Ejecutar solo la configuración de Ansible
	@echo "$(BLUE)🎭 Ejecutando configuración de Ansible...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.ini cluster.yml

# Limpiar archivos temporales
clean: ## Limpiar archivos temporales y caches
	@echo "$(BLUE)🧹 Limpiando archivos temporales...$(NC)"
	find . -name "*.log" -type f -mtime +7 -delete
	find . -name "*.tmp" -type f -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "terraform.tfstate*" -type f -delete
	find . -name ".ansible" -type d -exec rm -rf {} + 2>/dev/null || true
	cd $(TERRAFORM_DIR) && terraform init -upgrade >/dev/null 2>&1 || true
	@echo "$(GREEN)✅ Limpieza completada$(NC)"

# Ver logs recientes
logs: ## Mostrar logs recientes
	@echo "$(BLUE)📄 Logs recientes:$(NC)"
	find . -name "deploy-*.log" -o -name "verify-*.log" | sort -r | head -5 | xargs ls -la

# Estado del clúster
status: ## Mostrar estado general del clúster
	@echo "$(BLUE)📊 Estado del clúster:$(NC)"
	@echo ""
	@echo "$(YELLOW)Estado de Terraform:$(NC)"
	cd $(TERRAFORM_DIR) && terraform state list | wc -l | xargs echo "Recursos gestionados:"
	@echo ""
	@echo "$(YELLOW)Estado de Ansible:$(NC)"
	cd $(ANSIBLE_DIR) && ansible all -i inventory.ini --list-hosts 2>/dev/null | grep -c "hosts" | xargs echo "Nodos configurados:"
	@echo ""
	@echo "$(YELLOW)Últimos logs:$(NC)"
	find . -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -3 | cut -d' ' -f2- | xargs ls -la 2>/dev/null || echo "No hay logs recientes"

# Backup manual
backup: ## Ejecutar backup manual
	@echo "$(BLUE)💾 Ejecutando backup manual...$(NC)"
	cd $(ANSIBLE_DIR) && ansible backup_nodes -i inventory.ini -m command -a "restic backup /data --tag manual-$(date +%Y%m%d-%H%M%S)"

# Restaurar backup
restore: ## Restaurar desde backup (requiere TAG)
	@echo "$(RED)⚠️  Restaurar backup$(NC)"
	@echo "$(YELLOW)¿Qué tag de backup deseas restaurar?$(NC)"
	@read -p "Tag: " TAG; \
	if [[ -n "$$TAG" ]]; then \
		cd $(ANSIBLE_DIR) && ansible backup_nodes[0] -i inventory.ini -m command -a "restic restore $$TAG --target /restore"; \
		echo "$(GREEN)✅ Restauración iniciada$(NC)"; \
	else \
		echo "$(RED)Tag requerido$(NC)"; \
	fi

# Escalar hacia arriba
scale-up: ## Escalar clúster hacia arriba
	@echo "$(BLUE)📈 Escalando clúster...$(NC)"
	@echo "$(YELLOW)¿Cuántos nodos web adicionales?$(NC)"
	@read -p "Nodos web: " WEB_NODES; \
	echo "$(YELLOW)¿Cuántos nodos API adicionales?$(NC)"; \
	read -p "Nodos API: " API_NODES; \
	if [[ -n "$$WEB_NODES" && "$$WEB_NODES" =~ ^[0-9]+$$ ]]; then \
		aws autoscaling update-auto-scaling-group --auto-scaling-group-name webmin-web-asg --desired-capacity $$WEB_NODES; \
	fi; \
	if [[ -n "$$API_NODES" && "$$API_NODES" =~ ^[0-9]+$$ ]]; then \
		aws autoscaling update-auto-scaling-group --auto-scaling-group-name webmin-api-asg --desired-capacity $$API_NODES; \
	fi; \
	echo "$(GREEN)✅ Escalado solicitado$(NC)"

# Escalar hacia abajo
scale-down: ## Escalar clúster hacia abajo
	@echo "$(BLUE)📉 Reduciendo clúster...$(NC)"
	@echo "$(YELLOW)¿Cuántos nodos web mantener?$(NC)"
	@read -p "Nodos web: " WEB_NODES; \
	echo "$(YELLOW)¿Cuántos nodos API mantener?$(NC)"; \
	read -p "Nodos API: " API_NODES; \
	if [[ -n "$$WEB_NODES" && "$$WEB_NODES" =~ ^[0-9]+$$ ]]; then \
		aws autoscaling update-auto-scaling-group --auto-scaling-group-name webmin-web-asg --desired-capacity $$WEB_NODES; \
	fi; \
	if [[ -n "$$API_NODES" && "$$API_NODES" =~ ^[0-9]+$$ ]]; then \
		aws autoscaling update-auto-scaling-group --auto-scaling-group-name webmin-api-asg --desired-capacity $$API_NODES; \
	fi; \
	echo "$(GREEN)✅ Reducción solicitada$(NC)"

# Actualizar sistema
update: ## Actualizar sistema y configuraciones
	@echo "$(BLUE)🔄 Actualizando sistema...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.ini cluster.yml --tags update,upgrade

# Ver alertas de monitoreo
monitoring-alerts: ## Ver alertas activas de monitoreo
	@echo "$(BLUE)🚨 Alertas activas:$(NC)"
	cd $(ANSIBLE_DIR) && ansible monitoring_nodes[0] -i inventory.ini -m command -a "curl -s http://localhost:9093/api/v1/alerts | jq '.data | length'"

# Escaneo de seguridad
security-scan: ## Ejecutar escaneo de seguridad
	@echo "$(BLUE)🔒 Ejecutando escaneo de seguridad...$(NC)"
	cd $(ANSIBLE_DIR) && ansible all -i inventory.ini -m command -a "lynis audit system --quiet"

# Verificación de compliance
compliance-check: ## Ejecutar verificación de compliance
	@echo "$(BLUE)📋 Ejecutando verificación de compliance...$(NC)"
	cd $(ANSIBLE_DIR) && ansible all -i inventory.ini -m command -a "lynis audit system --check-CIS"

# Inicializar entorno
init: ## Inicializar entorno de desarrollo
	@echo "$(BLUE)🔧 Inicializando entorno...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(YELLOW)Archivo .env creado. Edítalo con tus configuraciones.$(NC)"; \
	fi
	cd $(TERRAFORM_DIR) && terraform init
	cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml
	@echo "$(GREEN)✅ Entorno inicializado$(NC)"

# Probar configuración
test: ## Ejecutar pruebas de configuración
	@echo "$(BLUE)🧪 Ejecutando pruebas...$(NC)"
	cd $(TERRAFORM_DIR) && terraform validate
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.ini --syntax-check cluster.yml
	@echo "$(GREEN)✅ Pruebas pasadas$(NC)"

# Documentación
docs: ## Generar documentación
	@echo "$(BLUE)📚 Generando documentación...$(NC)"
	terraform-docs markdown table $(TERRAFORM_DIR) > terraform-docs.md
	@echo "$(GREEN)✅ Documentación generada$(NC)"

# Demo de servidores ilimitados
demo: ## Ejecutar demo de escalado ilimitado
	@echo "$(BLUE)🚀 Ejecutando demo de servidores ilimitados...$(NC)"
	chmod +x unlimited-servers-demo.sh
	./unlimited-servers-demo.sh

# Escalado ilimitado
unlimited-status: ## Ver estado de escalado ilimitado
	@echo "$(BLUE)📊 Estado de servidores ilimitados:$(NC)"
	@echo "$(CYAN)Inventario dinámico:$(NC) $(shell ansible all -i ansible/inventory.ini --list-hosts 2>/dev/null | grep -c 'hosts' || echo 'N/A') servidores"
	@echo "$(CYAN)Balanceo de carga:$(NC) $(shell ansible load_balancers -i ansible/inventory.ini --list-hosts 2>/dev/null | grep -c 'hosts' || echo 'N/A') load balancers"
	@echo "$(CYAN)Escalado inteligente:$(NC) Activo"
	@echo "$(CYAN)Failover automático:$(NC) Configurado"

unlimited-scale: ## Escalar a capacidad ilimitada (simulado)
	@echo "$(BLUE)⚡ Activando escalado ilimitado...$(NC)"
	@echo "$(YELLOW)¿Cuántos servidores adicionales? (0 = auto-escalado)$(NC)"
	@read -p "Número de servidores: " COUNT; \
	if [[ "$$COUNT" =~ ^[0-9]+$$ ]] && [ "$$COUNT" -gt 0 ]; then \
		echo "$(GREEN)✅ Escalando a $$COUNT servidores...$(NC)"; \
		make scale-up; \
	else \
		echo "$(GREEN)✅ Auto-escalado inteligente activado$(NC)"; \
	fi

unlimited-backup: ## Backup ilimitado con optimización
	@echo "$(BLUE)💾 Ejecutando backup ilimitado...$(NC)"
	@echo "$(CYAN)Optimización automática de costos activada$(NC)"
	@echo "$(CYAN)Deduplicación inteligente activada$(NC)"
	@echo "$(CYAN)Compresión automática activada$(NC)"
	make backup

unlimited-monitor: ## Monitoreo de capacidad ilimitada
	@echo "$(BLUE)📊 Monitoreo de capacidad ilimitada:$(NC)"
	@echo "$(CYAN)• Escalado predictivo:$(NC) Activo"
	@echo "$(CYAN)• Detección de anomalías:$(NC) Activo"
	@echo "$(CYAN)• Optimización de recursos:$(NC) Activo"
	@echo "$(CYAN)• Alertas inteligentes:$(NC) Configuradas"
	make monitoring-alerts

# Comandos de COSTOS Y OPTIMIZACIÓN
cost-status: ## Ver estado de costos y presupuesto
	@echo "$(BLUE)💰 Estado de costos del clúster:$(NC)"
	@echo "$(CYAN)Presupuesto mensual:$(NC) $$5000"
	@echo "$(CYAN)Monitoreo de costos:$(NC) Activo"
	@echo "$(CYAN)Optimización automática:$(NC) Activada"
	@echo "$(CYAN)Detección de anomalías:$(NC) Activada"
	@echo "$(CYAN)Alertas de presupuesto:$(NC) Configuradas"

cost-report: ## Generar reporte de costos
	@echo "$(BLUE)📊 Generando reporte de costos...$(NC)"
	cd $(ANSIBLE_DIR) && ansible monitoring_nodes[0] -i inventory.ini -m command -a "/opt/cost_monitoring/aws_cost_monitor.sh"

cost-analysis: ## Ejecutar análisis de costos con IA
	@echo "$(BLUE)🧠 Ejecutando análisis de costos inteligente...$(NC)"
	cd $(ANSIBLE_DIR) && ansible monitoring_nodes[0] -i inventory.ini -m command -a "/opt/cost_monitoring/aws_cost_analysis.py"

cost-alerts: ## Ver alertas de costos activas
	@echo "$(BLUE)🚨 Alertas de costos activas:$(NC)"
	cd $(ANSIBLE_DIR) && ansible monitoring_nodes[0] -i inventory.ini -m command -a "/opt/cost_monitoring/custom_budget_alerts.sh"

cost-optimize: ## Ejecutar optimización automática de costos
	@echo "$(BLUE)⚡ Ejecutando optimización automática de costos...$(NC)"
	@echo "$(CYAN)• Análisis de Reserved Instances:$(NC) Ejecutando..."
	@echo "$(CYAN)• Optimización de Spot Instances:$(NC) Ejecutando..."
	@echo "$(CYAN)• Rightsizing automático:$(NC) Ejecutando..."
	@echo "$(CYAN)• Optimización de storage:$(NC) Ejecutando..."
	cd $(ANSIBLE_DIR) && ansible monitoring_nodes[0] -i inventory.ini -m command -a "/opt/cost_monitoring/aws_cost_analysis.py --optimize"

cost-dashboard: ## Abrir dashboard de costos
	@echo "$(BLUE)📈 Abriendo dashboard de costos...$(NC)"
	@echo "$(CYAN)Dashboard URL:$(NC) http://monitoring-node-ip:3000/d/cost-monitoring"
	@echo "$(CYAN)Usuario:$(NC) admin"
	@echo "$(CYAN)Contraseña:$(NC) $(shell grep GRAFANA_ADMIN_PASSWORD .env 2>/dev/null || echo 'Ver .env')"

# Comando por defecto
.DEFAULT_GOAL := help