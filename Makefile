

all: create label taint helm nginx grafana prometheus loki alloy workload

create:
	k3d cluster create internship \
  	--servers 1 \
  	--agents 2 \
	--api-port 127.0.0.1:6550 \
  	--k3s-arg "--disable=traefik@server:0" \
  	--wait
	k3d cluster edit internship \
	--port-add "127.0.0.1:80:80@loadbalancer"
	k3d cluster edit internship \
	--port-add "127.0.0.1:443:443@loadbalancer"

label:
	kubectl label node k3d-internship-agent-0 \
	workload-role=monitoring \
	--overwrite
	kubectl label node k3d-internship-agent-1 \
	workload-role=worker \
	--overwrite
	kubectl label node k3d-internship-agent-0 \
	node-role.kubernetes.io/monitoring=monitoring \
	--overwrite
	kubectl label node k3d-internship-agent-1 \
	node-role.kubernetes.io/worker=worker \
	--overwrite

# set the node to No scheduling, mean that if a pod is deployed
# it can not be deployed in the node exept if the taint allow it
taint:
	kubectl taint node k3d-internship-agent-0 \
	dedicated=monitoring:NoSchedule \
  	--overwrite

helm:
	helm repo add grafana-community \
	https://grafana-community.github.io/helm-charts \
	--force-update
	helm repo add prometheus-community \
	https://prometheus-community.github.io/helm-charts
	helm repo add grafana \
	https://grafana.github.io/helm-charts
	helm repo add grafana-community \
	https://grafana-community.github.io/helm-charts
	helm repo add ingress-nginx \
	https://kubernetes.github.io/ingress-nginx
	helm repo update

nginx:
	helm upgrade --install ingress-nginx \
	ingress-nginx/ingress-nginx \
	--namespace ingress-nginx \
	--create-namespace \
	--set controller.nodeSelector.workload-role=monitoring \
	--set controller.tolerations[0].key=dedicated \
	--set controller.tolerations[0].operator=Equal \
	--set controller.tolerations[0].value=monitoring \
	--set controller.tolerations[0].effect=NoSchedule \
	--wait \
	--timeout 10m

grafana:
	helm upgrade --install grafana \
	grafana-community/grafana \
	--namespace monitoring \
	--create-namespace \
	--values values/grafana_values.yaml \
	--wait \
	--timeout 10m
	kubectl apply -f ingress/grafana_ingress.yaml

grafana-pwd:
	   kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

prometheus:
	helm upgrade --install prometheus \
	prometheus-community/kube-prometheus-stack \
	--namespace monitoring \
	--values values/prometheus_values.yaml \
	--wait \
	--timeout 15m
	kubectl apply -f ingress/prometheus_ingress.yaml

loki:
	helm upgrade --install loki \
	grafana-community/loki \
	--namespace monitoring \
	--values values/loki_values.yaml \
	--wait \
	--timeout 15m

alloy:
	helm upgrade --install alloy \
	grafana/alloy \
	--namespace monitoring \
	--values values/alloy_values.yaml \
	--wait \
	--timeout 10m

workload:
	kubectl apply -f workload/dummy_logger.yaml

info:
	@printf "  %-15s %s\n" "### k3d INFO ###"
	kubectl cluster-info
	@printf "  %-15s %s\n" "### cluster INFO ###"
	kubectl get nodes -o wide
	kubectl get nodes --show-labels
	@printf "  %-15s %s\n" "### docker INFO ###"
	docker ps --filter name=k3d-internship

clean:
	k3d cluster delete internship

re: clean all

help:
	@echo "K3d Kubernetes Observability Lab"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Cluster:"
	@echo "  help          Show this help message"
	@echo "  create        Create the k3d cluster"
	@echo "  label         Add monitoring and worker node labels"
	@echo "  taint         Reserve the monitoring node"
	@echo "  info          Show cluster, node, pod, and Docker information"
	@echo ""
	@echo "Observability:"
	@echo "  helm          Add and update Helm repositories"
	@echo "  grafana       Install or upgrade Grafana"
	@echo "  grafana-pwd   Print the Grafana administrator password"
	@echo "  prometheus    Install or upgrade Prometheus"
	@echo "  loki          Install or upgrade Loki"
	@echo "  alloy         Install or upgrade Grafana Alloy"
	@echo "  nginx         Install or upgrade ingress-nginx"
	@echo ""
	@echo "Workloads:"
	@echo "  workload      Deploy the dummy logging workload"
	@echo ""
	@echo "Lifecycle:"
	@echo "  all           Create the cluster and install everything"
	@echo "  clean         Delete the k3d cluster"
	@echo "  re            Delete and recreate the complete environment"
	@echo ""
	@echo "Service URLs:"
	@echo "  Grafana:      http://grafana.localhost"
	@echo "  Prometheus:   http://prometheus.localhost"

.PHONY: create \
		info \
		clean \
		all \
		re \
		taint \
		grafana \
		grafana-pwd \
		helm \
		prometheus \
		loki \
		alloy \
		nginx \
		workload \
		help \
