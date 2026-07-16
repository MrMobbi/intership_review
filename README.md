# K3d Kubernetes Observability Lab

A local multi-node Kubernetes observability environment built with **k3d/k3s**, **Grafana**, **Prometheus**, **Loki**, **Grafana Alloy**, and **ingress-nginx**.

This project was created as part of an internship review to demonstrate:

- Creating and managing a local Kubernetes cluster
- Assigning dedicated roles to Kubernetes nodes
- Controlling pod placement with labels, selectors, taints, and tolerations
- Installing applications with Helm
- Collecting Kubernetes metrics with Prometheus
- Collecting pod logs and Kubernetes events with Grafana Alloy
- Storing and querying logs with Loki
- Visualizing metrics and logs in Grafana
- Exposing services through Kubernetes Ingress
- Deploying a dummy workload that continuously generates test logs

> This repository is intended for learning, testing, and demonstrations. It is not a production-ready Kubernetes or observability deployment.

## Architecture

~~~text
Arch Linux host
└── Docker
    └── k3d cluster: internship
        ├── k3d-internship-server-0
        │   └── k3s control plane
        │
        ├── k3d-internship-agent-0
        │   ├── role: monitoring
        │   ├── Grafana
        │   ├── Prometheus
        │   ├── Loki
        │   ├── Alloy
        │   └── ingress-nginx
        │
        └── k3d-internship-agent-1
            ├── role: worker
            └── dummy logger pods
~~~

Observability data flow:

~~~text
Dummy pods
   │
   ├── Kubernetes metrics ────────────────► Prometheus
   │                                          │
   └── stdout logs ─► Alloy ─► Loki           │
                              │                │
                              └────► Grafana ◄─┘
~~~

External access:

~~~text
Browser
  │
  └── k3d load balancer
        └── ingress-nginx
              ├── grafana.localhost    ─► Grafana
              └── prometheus.localhost ─► Prometheus
~~~

## Components

| Component | Purpose |
|---|---|
| k3d | Runs a local k3s cluster inside Docker containers |
| k3s | Lightweight Kubernetes distribution |
| Helm | Installs and configures the monitoring applications |
| Grafana | Displays dashboards and provides metrics/log exploration |
| Prometheus | Collects and stores Kubernetes metrics |
| kube-state-metrics | Exposes Kubernetes object state as Prometheus metrics |
| node-exporter | Exposes node-level metrics |
| Loki | Stores and queries logs |
| Grafana Alloy | Discovers Kubernetes pods and forwards logs/events to Loki |
| ingress-nginx | Routes local HTTP traffic to Grafana and Prometheus |
| BusyBox dummy logger | Generates structured test logs |

## Node placement

The cluster contains one control-plane node and two agent nodes.

| Node | Kubernetes role | Workload label | Purpose |
|---|---|---|---|
| `k3d-internship-server-0` | `control-plane,master` | None | Kubernetes control plane |
| `k3d-internship-agent-0` | `monitoring` | `workload-role=monitoring` | Observability stack |
| `k3d-internship-agent-1` | `worker` | `workload-role=worker` | Dummy application workloads |

The monitoring node is tainted with:

~~~text
dedicated=monitoring:NoSchedule
~~~

Monitoring components have a matching toleration. This prevents ordinary workloads from being scheduled on the monitoring node accidentally.

## Repository structure

~~~text
.
├── Makefile
├── README.md
├── ingress/
│   ├── grafana_ingress.yaml
│   └── prometheus_ingress.yaml
├── values/
│   ├── alloy_values.yaml
│   ├── grafana_values.yaml
│   ├── loki_values.yaml
│   └── prometheus_values.yaml
└── workload/
    └── dummy_logger.yaml
~~~

## Prerequisites

The following tools are required:

- Docker
- k3d
- kubectl
- Helm
- GNU Make
- Git

### Arch Linux

Install the packages available in the official repositories:

~~~bash
sudo pacman -Syu --needed docker kubectl helm make git
sudo systemctl enable --now docker
~~~

Install k3d from the AUR using an AUR helper:

~~~bash
paru -S k3d-bin
~~~

Allow the current user to run Docker commands:

~~~bash
sudo usermod -aG docker "$USER"
~~~

Log out and log back in, then verify the tools:

~~~bash
docker info
k3d version
kubectl version --client
helm version
make --version
~~~

## Ports

The current Makefile maps the following host ports to the k3d load balancer:

| Host port | Cluster port | Purpose |
|---:|---:|---|
| `80` | `80` | HTTP Ingress |
| `443` | `443` | HTTPS Ingress |
| `8080` | `80` | Alternative HTTP access |
| `8443` | `443` | Alternative HTTPS access |
| `6550` | `6443` | Kubernetes API |

Check that the ports are free before creating the cluster:

~~~bash
sudo ss -ltnp | grep -E ':(80|443|8080|8443|6550)\b' || true
~~~

## Installation

Clone the repository:

~~~bash
git clone https://github.com/MrMobbi/intership_review.git
cd intership_review
~~~

### 1. Create the cluster and install the observability stack

~~~bash
make all
~~~

This target performs the following operations:

1. Creates the k3d cluster
2. Labels the monitoring and worker nodes
3. Taints the monitoring node
4. Adds the required Helm repositories
5. Installs Grafana
6. Installs Prometheus
7. Installs Loki
8. Installs Alloy

### 2. Install the Ingress controller

The Grafana and Prometheus Ingress resources require ingress-nginx:

~~~bash
make nginx
~~~

### 3. Deploy the dummy logging workload

~~~bash
kubectl apply -f workload/dummy_logger.yaml
~~~

The deployment creates three BusyBox pods in the `demo` namespace. The pods are scheduled on the worker node and continuously generate `info`, `warn`, and `error` log messages.

### 4. Verify the installation

~~~bash
make info
~~~

Check all Kubernetes pods:

~~~bash
kubectl get pods -A -o wide
~~~

Check node roles and workload labels:

~~~bash
kubectl get nodes -L workload-role
~~~

Check the monitoring namespace:

~~~bash
kubectl get pods,svc,pvc,ingress -n monitoring -o wide
~~~

Check the dummy workload:

~~~bash
kubectl get pods -n demo -o wide
~~~

The dummy pods should run on:

~~~text
k3d-internship-agent-1
~~~

## Accessing the services

### Grafana

Open:

~~~text
http://grafana.localhost
~~~

Alternative port:

~~~text
http://grafana.localhost:8080
~~~

The username is:

~~~text
admin
~~~

Retrieve the generated password:

~~~bash
make grafana-pwd
~~~

### Prometheus

Open:

~~~text
http://prometheus.localhost
~~~

Alternative port:

~~~text
http://prometheus.localhost:8080
~~~

If the `.localhost` names do not resolve on the host, add them manually:

~~~bash
echo '127.0.0.1 grafana.localhost prometheus.localhost' |
  sudo tee -a /etc/hosts
~~~

## Configuring Grafana data sources

Open Grafana and navigate to:

~~~text
Connections → Data sources → Add new data source
~~~

### Prometheus data source

Use:

~~~text
Name: Prometheus
Type: Prometheus
URL:  http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
~~~

Click **Save & test**.

### Loki data source

Use:

~~~text
Name: Loki
Type: Loki
URL:  http://loki-gateway.monitoring.svc.cluster.local
~~~

Click **Save & test**.

The internal Kubernetes service addresses are used because Grafana connects to the data sources from inside the cluster.

## Importing Grafana dashboards

Dashboards are imported manually from the Grafana dashboard catalog.

In Grafana, navigate to:

~~~text
Dashboards → New → Import
~~~

Enter one dashboard ID at a time and select the correct data source when prompted.

| Dashboard ID | Dashboard | Data source |
|---:|---|---|
| `15757` | Kubernetes / Views / Global | Prometheus |
| `15758` | Kubernetes / Views / Namespaces | Prometheus |
| `18494` | Kubernetes Logs from Loki | Loki |

The first two dashboards provide global and namespace-level Kubernetes metrics. The Loki dashboard provides namespace and pod filters for viewing application logs.

## Testing Prometheus

Open **Grafana Explore**, select the Prometheus data source, and run:

~~~promql
up
~~~

Count cluster nodes:

~~~promql
count(kube_node_info)
~~~

Count running pods in the demo namespace:

~~~promql
sum(kube_pod_status_phase{namespace="demo", phase="Running"})
~~~

Check the dummy deployment replicas:

~~~promql
kube_deployment_status_replicas_available{
  namespace="demo",
  deployment="dummy-logger"
}
~~~

## Testing Loki

Confirm that the dummy workload is generating logs:

~~~bash
kubectl logs \
  -n demo \
  -l app=dummy-logger \
  --all-containers=true \
  --prefix \
  --tail=30
~~~

Open **Grafana Explore**, select Loki, and run:

~~~logql
{namespace="demo"}
~~~

Show only the dummy logger:

~~~logql
{namespace="demo", container="logger"}
~~~

Show simulated warning messages:

~~~logql
{namespace="demo"} |= "level=warn"
~~~

Show simulated errors:

~~~logql
{namespace="demo"} |= "level=error"
~~~

Filter logs by cluster:

~~~logql
{cluster="internship-k3d"}
~~~

View Kubernetes events collected by Alloy:

~~~logql
{job="kubernetes/events"}
~~~

## Demonstration scenarios

### Scale the dummy workload

~~~bash
kubectl scale deployment dummy-logger \
  --namespace demo \
  --replicas=6
~~~

Watch the pods:

~~~bash
kubectl get pods -n demo -o wide --watch
~~~

Prometheus should show the replica count increasing, while Loki should show logs from the new pods.

### Demonstrate self-healing

Delete one of the dummy pods:

~~~bash
kubectl delete pod \
  -n demo \
  "$(kubectl get pods -n demo -o jsonpath='{.items[0].metadata.name}')"
~~~

Kubernetes will automatically create a replacement pod because the workload is managed by a Deployment.

### Generate a Kubernetes warning event

~~~bash
kubectl run broken-demo \
  --namespace demo \
  --image=this-image-does-not-exist.invalid/demo:latest
~~~

Inspect the event:

~~~bash
kubectl get events -n demo --sort-by='.lastTimestamp'
~~~

Query the event in Loki:

~~~logql
{job="kubernetes/events", namespace="demo"}
~~~

Remove the broken pod afterward:

~~~bash
kubectl delete pod broken-demo -n demo
~~~

## Useful Make targets

| Command | Description |
|---|---|
| `make create` | Create the k3d cluster and expose host ports |
| `make label` | Apply monitoring and worker node labels |
| `make taint` | Reserve the monitoring node |
| `make helm` | Add and update Helm repositories |
| `make grafana` | Install or upgrade Grafana |
| `make grafana-pwd` | Print the Grafana administrator password |
| `make prometheus` | Install or upgrade kube-prometheus-stack |
| `make loki` | Install or upgrade Loki |
| `make alloy` | Install or upgrade Alloy |
| `make nginx` | Install or upgrade ingress-nginx |
| `make info` | Display cluster, node, and container information |
| `make clean` | Delete the k3d cluster |
| `make re` | Delete and recreate the cluster |
| `make all` | Create the cluster and install the core observability stack |

## Troubleshooting

### A pod remains Pending

Inspect its scheduling events:

~~~bash
kubectl describe pod -n <namespace> <pod-name>
~~~

Verify the node labels:

~~~bash
kubectl get nodes -L workload-role
~~~

Verify the monitoring-node taint:

~~~bash
kubectl describe node k3d-internship-agent-0 | grep -A2 Taints
~~~

### Ingress does not respond

Check ingress-nginx:

~~~bash
kubectl get pods,svc -n ingress-nginx -o wide
~~~

Check the Ingress resources:

~~~bash
kubectl get ingress -n monitoring
~~~

Test host-based routing directly:

~~~bash
curl -I -H 'Host: grafana.localhost' http://127.0.0.1
curl -I -H 'Host: prometheus.localhost' http://127.0.0.1
~~~

### Grafana cannot connect to Prometheus or Loki

Check service names:

~~~bash
kubectl get svc -n monitoring
~~~

Test Prometheus from inside the cluster:

~~~bash
kubectl run prometheus-test \
  --namespace monitoring \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -s \
  http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/-/ready
~~~

Test Loki:

~~~bash
kubectl run loki-test \
  --namespace monitoring \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -s \
  http://loki-gateway.monitoring.svc.cluster.local/ready
~~~

### Logs do not appear in Loki

Check Alloy:

~~~bash
kubectl get pods -n monitoring -l app.kubernetes.io/instance=alloy
~~~

Inspect Alloy logs:

~~~bash
kubectl logs \
  -n monitoring \
  deployment/alloy \
  -c alloy \
  --tail=100
~~~

Confirm that the source pods produce logs:

~~~bash
kubectl logs -n demo -l app=dummy-logger --tail=20
~~~

## Cleanup

Delete only the dummy workload:

~~~bash
kubectl delete -f workload/dummy_logger.yaml
~~~

Delete the complete k3d cluster:

~~~bash
make clean
~~~

Recreate everything:

~~~bash
make re
make nginx
kubectl apply -f workload/dummy_logger.yaml
~~~

## Limitations

- All Kubernetes nodes run as Docker containers on a single host.
- A host failure stops every cluster node.
- Loki uses a single monolithic replica and local filesystem storage.
- Prometheus and Loki are configured for a small demonstration environment.
- Prometheus is exposed locally without authentication.
- TLS is not configured for the Ingress resources.
- Persistent data is local to the k3d environment and should not be treated as a backup.
- The setup is designed for education and internship demonstration purposes, not production.

## References

- [k3d documentation](https://k3d.io/)
- [k3s documentation](https://docs.k3s.io/)
- [Kubernetes documentation](https://kubernetes.io/docs/)
- [Grafana documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus documentation](https://prometheus.io/docs/)
- [Loki documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Alloy documentation](https://grafana.com/docs/alloy/latest/)
- [ingress-nginx documentation](https://kubernetes.github.io/ingress-nginx/)
