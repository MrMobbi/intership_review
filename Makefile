

all: create label taint helm grafana

create:
	k3d cluster create internship \
  	--servers 1 \
  	--agents 2 \
	--api-port 127.0.0.1:6550 \
  	--k3s-arg "--disable=traefik@server:0" \
  	--wait

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
	helm repo update

grafana:
	helm upgrade --install grafana \
	grafana-community/grafana \
	--namespace monitoring \
	--create-namespace \
	--values grafana_values.yaml \
	--wait \
	--timeout 10m

grafana-pwd:
	   kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

prometheus:
	helm upgrade --install prometheus \
	prometheus-community/kube-prometheus-stack \
	--namespace monitoring \
	--values prometheus_values.yaml \
	--wait \
	--timeout 15m

loki:
	helm upgrade --install loki \
	grafana-community/loki \
	--namespace monitoring \
	--values loki_values.yaml \
	--wait \
	--timeout 15m

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
