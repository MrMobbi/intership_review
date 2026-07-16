

all: create label

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
