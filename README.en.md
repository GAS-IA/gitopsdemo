# GitOps Demo with Argo CD

English version. For Portuguese, see [README.md](README.md).

This repository contains a GitOps demo with a Flask application and three backend services: PostgreSQL, RabbitMQ and Redis.

The application records operational incidents and lets you send the same payload to one backend or to all backends at once.

> Important notes:
> - I know a monorepo is not the best choice for GitOps. The decision here is intentional: (1) keep everything in one place and avoid the extra complexity of multiple repositories; (2) fit the time and flow of the presentation; (3) keep the demo introductory.
> - Among the problems with monorepos, one is mixing application-code commits with operations commits. To make that visible, I will use `[CODE]` for application code and `[GITOPS]` for operations changes.
> - I am not covering infrastructure provisioning. This is probably the weakest point of the explanation, because GitOps is mainly about operations and automated infrastructure provisioning is one of its basic assumptions. The same presentation constraints apply here.
> - Using a public repository and including secrets in the repository deserves strong criticism, including mine. For this demo, the teaching goal wins: I am leaving security aside so everyone can access what needs to be shown. Do not ignore security when applying these ideas in a real environment.

## Architecture

- `src/app.py`: Flask application.
- `src/requirements.txt`: Python dependencies installed during pod startup.
- `manifests/services`: Kubernetes manifests for the backend services.
- `manifests/app`: Kubernetes manifests for the Flask application.
- `manifests/argocd`: Argo CD `AppProject` and `Application` resources.
- `.github/workflows/generate-configmaps.yaml`: workflow that generates app ConfigMaps from `src`.
- `.github/workflows/code-checks.yaml`: workflow that runs code checks and linting.
- `scripts/validate-backends.sh`: backend validation script.

The demo does not build a container image for the application. The application pod uses `python:3.12-slim`, mounts `app.py` and `requirements.txt` from ConfigMaps, installs dependencies into `/tmp/python-deps`, and starts:

```bash
gunicorn --bind 0.0.0.0:8080 app:app
```

## Prerequisites

- Kubernetes cluster with a default `StorageClass`.
- `kubectl` configured for the cluster.
- Argo CD installed in the `argocd` namespace.
- Git repository published to a remote URL that Argo CD can access.
- GitHub Actions enabled if you want automated ConfigMap generation.

If Argo CD is not installed yet, follow [docs/argocd-install.md](docs/argocd-install.md).

Confirm cluster access:

```bash
kubectl get nodes
kubectl get pods -n argocd
```

## Expected structure

```text
.
├── .github/workflows
│   ├── code-checks.yaml
│   └── generate-configmaps.yaml
├── docs
│   ├── argocd-install.md
│   └── gitops-demo-plan.md
├── manifests
│   ├── app
│   │   ├── 00-namespace.yaml
│   │   ├── code.yaml
│   │   ├── config.yaml
│   │   ├── deployment.yaml
│   │   ├── requirements.yaml
│   │   ├── secret.yaml
│   │   └── service.yaml
│   ├── argocd
│   │   ├── 01-app-project.yaml
│   │   ├── 02-repository.yaml
│   │   ├── 03-application-services.yaml
│   │   └── 04-application-app.yaml
│   └── services
│       ├── 00-namespace.yaml
│       ├── postgresql.yaml
│       ├── rabbitmq.yaml
│       └── redis.yaml
├── scripts
│   └── validate-backends.sh
└── src
    ├── app.py
    └── requirements.txt
```

## 1. Validate manifests

```bash
kubectl apply --dry-run=client -f manifests/services
kubectl apply --dry-run=client -f manifests/app
kubectl apply --dry-run=client -n argocd -f manifests/argocd
```

To apply the resources without Argo CD:

```bash
kubectl apply -f manifests/services
kubectl apply -f manifests/app
```

## 2. Configure the Argo CD repository URL

Update `repoURL` in the files under `manifests/argocd`. The initial placeholder is:

```text
https://github.com/REPLACE_ME/gitops-demo.git
```

Example:

```yaml
source:
  repoURL: https://github.com/your-org/your-repo.git
  targetRevision: main
```

The services `Application` points to `manifests/services`. The app `Application` points to `manifests/app`.

If the repository is private, update `manifests/argocd/repository.yaml` with a GitHub username and a read token before applying the manifests. Do not commit real tokens to the repository.

## 3. Generate application ConfigMaps

The workflow `.github/workflows/generate-configmaps.yaml` generates:

- `manifests/app/code.yaml` from `src/app.py`.
- `manifests/app/requirements.yaml` from `src/requirements.txt`.

After changing `src/app.py` or `src/requirements.txt`, run the workflow or push to the watched branch. Confirm both generated files are committed before Argo CD syncs the application.

On pull requests, the workflow only validates that the generated files are up to date. On pushes to `main` or `master`, it commits generated ConfigMaps when there are changes.

## 4. Apply the Argo CD bootstrap

With Argo CD already installed:

```bash
kubectl apply -n argocd -f manifests/argocd
```

Check the Applications:

```bash
kubectl get appproj -n argocd
kubectl get secret -n argocd  # Check Repository
kubectl get applications -n argocd
kubectl describe application gitops-demo-services -n argocd
kubectl describe application gitops-demo-app -n argocd
```

With the Argo CD CLI:

```bash
argocd app list
argocd app sync gitops-demo-services
argocd app sync gitops-demo-app
```

## 5. Confirm pods and services

Backends:

```bash
kubectl get pods,svc,pvc -n gitops-demo-services
```

Application:

```bash
kubectl get pods,svc -n gitops-demo-app
```

All pods should be `Running` or `Completed`, and PVCs should be `Bound`.

## 6. Access the application

Use port-forward:

```bash
kubectl -n gitops-demo-app port-forward svc/gitops-demo-app 8080:8080
```

Open:

```text
http://localhost:8080
```

Fill in the incident form and test the buttons:

- `PostgreSQL`
- `RabbitMQ`
- `Redis`
- `All`

## 7. Validate each backend

Use the validation script:

```bash
./scripts/validate-backends.sh
```

It runs the PostgreSQL, RabbitMQ and Redis checks documented below. The script supports optional environment variables such as `SERVICES_NAMESPACE`.

PostgreSQL:

```bash
kubectl -n gitops-demo-services exec deploy/postgresql -- \
  psql -U gitops_demo -d incidents -c "select id, title, service_name, severity, submitted_at from incident_submissions order by submitted_at desc limit 5;"
```

RabbitMQ:

```bash
kubectl -n gitops-demo-services exec deploy/rabbitmq -- \
  rabbitmqctl list_queues name messages durable
```

Redis count:

```bash
kubectl -n gitops-demo-services exec deploy/redis -- \
  sh -c 'redis-cli -a "$REDIS_PASSWORD" llen incident_submissions:ids'
```

Redis IDs:

```bash
kubectl -n gitops-demo-services exec deploy/redis -- \
  sh -c 'redis-cli -a "$REDIS_PASSWORD" lrange incident_submissions:ids 0 4'
```

## 8. Test persistence

Restart backend deployments:

```bash
kubectl -n gitops-demo-services rollout restart deploy/postgresql
kubectl -n gitops-demo-services rollout restart deploy/rabbitmq
kubectl -n gitops-demo-services rollout restart deploy/redis
```

Wait for rollout completion:

```bash
kubectl -n gitops-demo-services rollout status deploy/postgresql
kubectl -n gitops-demo-services rollout status deploy/rabbitmq
kubectl -n gitops-demo-services rollout status deploy/redis
```

Run `./scripts/validate-backends.sh` again. Data persisted in PostgreSQL, Redis and RabbitMQ should still be available.

## 9. Optional local development

Create a virtual environment and install dependencies:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r src/requirements.txt
```

Expose backends with port-forward:

```bash
kubectl -n gitops-demo-services port-forward svc/postgresql 5432:5432
kubectl -n gitops-demo-services port-forward svc/rabbitmq 5672:5672
kubectl -n gitops-demo-services port-forward svc/redis 6379:6379
```

In another terminal:

```bash
export POSTGRES_HOST=127.0.0.1
export RABBITMQ_HOST=127.0.0.1
export REDIS_HOST=127.0.0.1
python src/app.py
```

Access `http://localhost:8080`.

## Code checks

The workflow `.github/workflows/code-checks.yaml` runs:

- `ruff check src`
- Python bytecode compilation for `src/app.py`
- shell syntax validation for `scripts/validate-backends.sh`

Run the local checks manually:

```bash
bash -n scripts/validate-backends.sh
python3 -c "from pathlib import Path; compile(Path('src/app.py').read_text(), 'src/app.py', 'exec')"
```

## Cleanup

Remove Argo CD Applications:

```bash
kubectl delete -n argocd -f manifests/argocd
```

Remove synced resources if needed:

```bash
kubectl delete namespace gitops-demo-app
kubectl delete namespace gitops-demo-services
```

This also removes PVCs in the `gitops-demo-services` namespace.

## Troubleshooting

If the application starts before backends are ready, it stays up. When a button is clicked, the corresponding backend is initialized again before sending data.

If pods stay `Pending`, check the default `StorageClass`:

```bash
kubectl get storageclass
kubectl describe pvc -n gitops-demo-services
```
