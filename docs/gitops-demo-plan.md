# Plano Da Demo GitOps Com Argo CD

## Resumo

Criar uma demo GitOps em monorepo com aplicação Flask em `src`, manifests
Kubernetes em `manifests`, scripts operacionais em `scripts`, documentação em
português e inglês, e Argo CD sincronizando tudo a partir do repositório.

A aplicação tem um formulário de registro de incidentes de operação com 6 campos
e 4 botões para gravar/publicar dados em PostgreSQL, RabbitMQ, Redis ou todos
ao mesmo tempo.

A demo evita build de imagem: uma GitHub Action gera ConfigMaps a partir de
`src/app.py` e `src/requirements.txt`; o pod usa `python:3.12-slim`, monta os
arquivos em `/app`, instala dependências em runtime e inicia a aplicação.

## Estrutura

- Aplicação:
  - `src/app.py`
  - `src/requirements.txt`
- Documentação:
  - `README.md`
  - `README.en.md`
  - `docs/gitops-demo-plan.md`
  - `docs/argocd-install.md`
- Scripts:
  - `scripts/validate-backends.sh`
- Manifests da aplicação:
  - `manifests/app/00-namespace.yaml`
  - `manifests/app/config.yaml`
  - `manifests/app/secret.yaml`
  - `manifests/app/deployment.yaml`
  - `manifests/app/service.yaml`
  - `manifests/app/code.yaml`
  - `manifests/app/requirements.yaml`
- Manifests dos serviços, em layout flat:
  - `manifests/services/00-namespace.yaml`
  - `manifests/services/postgresql.yaml`
  - `manifests/services/rabbitmq.yaml`
  - `manifests/services/redis.yaml`
- Manifests do Argo CD:
  - `manifests/argocd/01-app-project.yaml`
  - `manifests/argocd/02-repository.yaml`
  - `manifests/argocd/03-application-services.yaml`
  - `manifests/argocd/04-application-app.yaml`
- GitHub Actions:
  - `.github/workflows/generate-configmaps.yaml`
  - `.github/workflows/code-checks.yaml`

## Namespaces

- `argocd` para os recursos `Application` e `AppProject`.
- `gitops-demo-app` para a aplicação.
- `gitops-demo-services` para PostgreSQL, RabbitMQ e Redis.

## Argo CD

- Criar um `AppProject` chamado `gitops-demo`.
- Registrar o repositório Git no Argo CD com o Secret `gitops-demo-repository`.
- Manter placeholders comentados de `username` e `password` em
  `02-repository.yaml` para o caso de o repositório voltar a ser privado.
- Criar uma `Application` chamada `gitops-demo-services` para `manifests/services`.
- Criar uma `Application` chamada `gitops-demo-app` para `manifests/app`.
- Usar sync automático com `prune: true`, `selfHeal: true` e `CreateNamespace=true`.
- Usar o repositório real da demo nas `Application`:
  `https://github.com/GAS-IA/gitopsdemo.git`.
- Aplicar os manifests em ordem alfabética/numerada pelo diretório
  `manifests/argocd`.

## Aplicação

- Framework: Flask.
- Tema do formulário: registro de incidentes de operação.
- Campos:
  - `title`
  - `reporter`
  - `service_name`
  - `environment`
  - `severity`
  - `description`
- Botões:
  - PostgreSQL
  - RabbitMQ
  - Redis
  - Todos
- Inicialização:
  - Criar tabela PostgreSQL `incident_submissions` se não existir.
  - Declarar fila RabbitMQ `incident_submissions` se não existir.
  - Inicializar estrutura Redis usando chaves com prefixo `incident_submissions`.
- Healthcheck:
  - Rota HTTP `GET /healthz`.

## Serviços

- YAML direto, sem Helm.
- Single-node para demo.
- PVC simples por backend.
- Services `ClusterIP` com nomes DNS internos:
  - `postgresql.gitops-demo-services.svc.cluster.local`
  - `rabbitmq.gitops-demo-services.svc.cluster.local`
  - `redis.gitops-demo-services.svc.cluster.local`

## Runtime E ConfigMaps

- GitHub Action gera:
  - `manifests/app/code.yaml` a partir de `src/app.py`
  - `manifests/app/requirements.yaml` a partir de `src/requirements.txt`
- O container monta:
  - `/app/app.py`
  - `/app/requirements.txt`
- Startup command:
  - instalar dependências em `/tmp/python-deps`
  - exportar `PYTHONPATH=/tmp/python-deps`
  - iniciar `gunicorn --bind 0.0.0.0:8080 app:app`
- ConfigMap/Secret serão usados para variáveis de ambiente e credenciais, não
  para instalar dependências.

## GitHub Actions

- `generate-configmaps.yaml`:
  - Roda em `push`, `pull_request` e `workflow_dispatch`.
  - Gera `manifests/app/code.yaml` e `manifests/app/requirements.yaml`.
  - Em PR, valida se os ConfigMaps gerados estão atualizados.
  - Em push para `main` ou `master`, commita os ConfigMaps gerados quando houver
    diferença.
- `code-checks.yaml`:
  - Roda em `push`, `pull_request` e `workflow_dispatch`.
  - Executa `ruff check src`.
  - Executa compilação Python de `src`.
  - Executa validação de sintaxe shell em `scripts/validate-backends.sh`.

## Scripts

- `scripts/validate-backends.sh` executa os procedimentos da seção de validação
  dos backends do README:
  - consulta últimas submissões no PostgreSQL;
  - lista filas RabbitMQ;
  - consulta contagem e IDs recentes no Redis.
- Variáveis suportadas:
  - `SERVICES_NAMESPACE`
  - `POSTGRES_DEPLOYMENT`
  - `RABBITMQ_DEPLOYMENT`
  - `REDIS_DEPLOYMENT`

## Documentação

- `README.md` em português com o passo a passo principal.
- `README.en.md` em inglês com o mesmo fluxo operacional.
- `docs/argocd-install.md` com instalação do Argo CD usando manifests oficiais.
- As notas de escopo da demo deixam explícitas as simplificações: monorepo,
  repositório público, secrets no repositório apenas para fins didáticos e
  infraestrutura fora do escopo.

## Test Plan

- Validar manifests:
  - `kubectl apply --dry-run=client -f manifests/services`
  - `kubectl apply --dry-run=client -f manifests/app`
  - `kubectl apply --dry-run=client -n argocd -f manifests/argocd`
- Validar que `02-repository.yaml` registra o repositório usado pelas duas
  `Application`.
- Validar que a action gera `code.yaml` e `requirements.yaml`.
- Validar que a action de checks executa lint Python e sintaxe shell.
- Aplicar `manifests/argocd` no namespace `argocd` e confirmar que as duas
  Applications sincronizam.
- Testar cada botão da aplicação e validar persistência/publicação no backend
  correspondente.
- Rodar `./scripts/validate-backends.sh`.
- Reiniciar pods e confirmar que PVCs preservam dados dos serviços.

## Assumptions

- O Argo CD já estará instalado no cluster antes do bootstrap da demo.
- O bootstrap inicial dos recursos em `manifests/argocd` será feito manualmente
  com `kubectl apply`.
- O repositório Git remoto real da demo é `GAS-IA/gitopsdemo`.
- Se o repositório for privado, `02-repository.yaml` deverá receber uma
  credencial de leitura antes da sincronização real.
- Redis não tem tabela nativa; será usada uma estrutura equivalente com
  chaves/listas/hashes.
