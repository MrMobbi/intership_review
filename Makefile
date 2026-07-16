

create:
	k3d cluster create internship \
  	--servers 1 \
  	--agents 2 \
	--api-port 127.0.0.1:6550 \
  	--k3s-arg "--disable=traefik@server:0" \
  	--wait

info:
	kubectl cluster-info
	kubectl get nodes -o wide
	docker ps --filter name=k3d-internship

clean:
	k3d cluster delete internship
