.PHONY: help prepare deploy validate clean

help:
	@echo "Kubernetes Migration Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  prepare   - Prepare all nodes for Kubernetes"
	@echo "  deploy    - Deploy all Kubernetes components"
	@echo "  validate  - Validate cluster health"
	@echo "  clean     - Clean up resources"

prepare:
	@echo "🔧 Preparing infrastructure..."
	cd ansible && ansible-playbook -i inventory/hosts.ini playbooks/pre-migration-prep.yml

deploy:
	@echo "🚀 Deploying Kubernetes components..."
	cd scripts/deployment && ./deploy-all.sh

validate:
	@echo "🔍 Validating cluster..."
	cd scripts/validation && ./validate-cluster.sh

clean:
	@echo "🧹 Cleaning up..."
	kubectl delete namespace flask-app monitoring testing --ignore-not-found
