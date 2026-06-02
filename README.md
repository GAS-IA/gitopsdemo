# GitOps Demo com Argo CD

Versão em português, para inglês: [README.en.md](README.en.md).

Demo GitOps em monorepo com uma aplicacao Flask e tres servicos de backend: PostgreSQL, RabbitMQ e Redis.

A aplicação registra incidentes de operacao e permite enviar o mesmo payload para um backend especifico ou para todos ao mesmo tempo.

> Notas importantes:
> - Sei que monorepo não é a melhor escolha para GitOps. A decisão aqui é para: (1º) colocar tudo em um lugar só e não complicar com vários repositórios diferentes; (2º) respeitar a dinâmica e o tempo necessário para apresentar tudo; (3º) manter o caráter introdutório ao assunto.
> - Dentre os vários problemas relacionados a monorepo, temos a mistura de commits de código da aplicação com commits de operação. Para controlar isso vou usar as tags `[CODE]` para código e `[GITOPS]` para operação.
> - Não estou abordando a infraestrutura. Isso é talvez o ponto mais frágil da minha explicação porque GitOps é, antes de tudo, para operações e criar a infraestrutura de forma automatizada é uma das premissas básicas. Mais uma vez, as justificativas anteriores valem aqui.
> - A escolha de um repostitório público e de incluir secrets no repostório é alvo de críticas severas (inclusive minhas). Porém, vence como prioridade a diretriz didática e, por isso, vou deixar a segurança de lado para que todos tenham o acesso necessário ao que precisa ser feito e demonstrado. Não esqueça porém de considerar a segurança quando for aplicar esses conhecimentos em um cenário real.

## Arquitetura

- `src/app.py`: aplicação Flask.
- `src/requirements.txt`: dependências Python instaladas no startup do pod.
- `manifests/services`: manifests Kubernetes dos backends.
- `manifests/app`: manifests Kubernetes da aplicação Flask.
- `manifests/argocd`: `AppProject` e `Application` do Argo CD.
- `.github/workflows/generate-configmaps.yaml`: workflow que gera os ConfigMaps da aplicação a partir de `src`.
- `.github/workflows/code-checks.yaml`: workflow de checks e lint de código.
- `scripts/validate-backends.sh`: script de validação dos backends.

Status atual deste repositório:

- Já existem `src/app.py`, `src/requirements.txt` e `manifests/services`.
- Já existe `manifests/app` com os manifests da aplicação e os ConfigMaps gerados a partir de `src`.
- Já existe `.github/workflows/generate-configmaps.yaml` para atualizar os ConfigMaps quando `src` mudar.
- Já existe `manifests/argocd` com o `AppProject` e as `Applications` da demo.

A demo evita build de imagem. O pod da aplicação usa `python:3.12-slim`, monta `app.py` e `requirements.txt` como ConfigMaps, instala dependências em `/tmp/python-deps` e inicia:

```bash
gunicorn --bind 0.0.0.0:8080 app:app
```

## Pré-requisitos

- Cluster Kubernetes com uma `StorageClass` padrão.
- `kubectl` configurado para o cluster.
- Argo CD instalado no namespace `argocd`.
- Repositório publicado em um Git remoto acessivel pelo Argo CD.
- Permissão para executar GitHub Actions, se a geração dos ConfigMaps for feita pela workflow.

Se o Argo CD ainda não estiver instalado, siga [docs/argocd-install.md](docs/argocd-install.md).

Confirme o acesso ao cluster:

```bash
kubectl get nodes
kubectl get pods -n argocd
```

## Estrutura esperada

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

## 1. Validar manifests

```bash
kubectl apply --dry-run=client -f manifests/services
kubectl apply --dry-run=client -f manifests/app
kubectl apply --dry-run=client -n argocd -f manifests/argocd
```

Para aplicar os recursos sem Argo CD:

```bash
kubectl apply -f manifests/services
kubectl apply -f manifests/app
```

Para verificar se os serviços estão rodando:

```bash
kubectl -n gitops-demo-services get all,pvc,cm,secret
kubectl -n gitops-demo-app get all,cm,secret
```

## 2. Configurar o repositorio no Argo CD

Nos manifests em `manifests/argocd`, ajuste `repoURL` para o Git remoto desta demo. O valor inicial está como `https://github.com/REPLACE_ME/gitops-demo.git`.

Exemplo:

```yaml
source:
  repoURL: https://github.com/sua-org/seu-repo.git
  targetRevision: main
```

A `Application` de serviços deve apontar para `manifests/services`. A `Application` da aplicacao deve apontar para `manifests/app`.

Se o repositório for privado, ajuste `manifests/argocd/repository.yaml` com um usuário GitHub e um token com permissão de leitura antes de aplicar os manifests. Não commite tokens reais no repositório.

## 3. Gerar ConfigMaps da aplicação

A workflow `.github/workflows/generate-configmaps.yaml` gera:

- `manifests/app/code.yaml` a partir de `src/app.py`.
- `manifests/app/requirements.yaml` a partir de `src/requirements.txt`.

Depois de alterar `src/app.py` ou `src/requirements.txt`, rode a workflow ou faça push para a branch monitorada. Confirme que os dois arquivos foram gerados e commitados antes de sincronizar a aplicação pelo Argo CD.

Em `pull_request`, a workflow apenas valida se `manifests/app/code.yaml` e `manifests/app/requirements.yaml` estão atualizados. Em `push` para `main` ou `master`, ela commita os ConfigMaps gerados quando houver diferença.

## Checks de código

A workflow `.github/workflows/code-checks.yaml` executa:

- `ruff check src`
- compilação Python de `src`
- validação de sintaxe shell de `scripts/validate-backends.sh`

Para rodar checks básicos localmente:

```bash
bash -n scripts/validate-backends.sh
python3 -c "from pathlib import Path; compile(Path('src/app.py').read_text(), 'src/app.py', 'exec')"
```

## 4. Aplicar bootstrap do Argo CD

Com o Argo CD já instalado:

```bash
kubectl apply -n argocd -f manifests/argocd
```

Verifique as Applications:

```bash
kubectl get appproj -n argocd
kubectl get secret -n argocd  # Check Repository
kubectl get applications -n argocd
kubectl describe application gitops-demo-services -n argocd
kubectl describe application gitops-demo-app -n argocd
```

Se estiver usando a CLI do Argo CD:

```bash
argocd app list
argocd app sync gitops-demo-services
argocd app sync gitops-demo-app
```


## 5. Confirmar pods e serviços

Backends:

```bash
kubectl get pods,svc,pvc -n gitops-demo-services
```

Aplicação:

```bash
kubectl get pods,svc -n gitops-demo-app
```

Todos os pods devem ficar em `Running` ou `Completed`, e os PVCs devem ficar em `Bound`.

## 6. Acessar a aplicação

Use port-forward para expor a aplicação localmente:

```bash
kubectl -n gitops-demo-app port-forward svc/gitops-demo-app 8080:8080
```

Abra:

```text
http://localhost:8080
```

Preencha o formulário de incidente e teste os botões:

- `PostgreSQL`
- `RabbitMQ`
- `Redis`
- `Todos`

## 7. Validar cada backend

Use o script de validação:

```bash
./scripts/validate-backends.sh
```

Ele executa as validações de PostgreSQL, RabbitMQ e Redis listadas abaixo.
O script aceita variáveis opcionais como `SERVICES_NAMESPACE`.

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

Redis:

```bash
kubectl -n gitops-demo-services exec deploy/redis -- \
  sh -c 'redis-cli -a "$REDIS_PASSWORD" llen incident_submissions:ids'
```

Para listar alguns IDs:

```bash
kubectl -n gitops-demo-services exec deploy/redis -- \
  sh -c 'redis-cli -a "$REDIS_PASSWORD" lrange incident_submissions:ids 0 4'
```

## 8. Testar persistência

Reinicie os deployments dos backends:

```bash
kubectl -n gitops-demo-services rollout restart deploy/postgresql
kubectl -n gitops-demo-services rollout restart deploy/rabbitmq
kubectl -n gitops-demo-services rollout restart deploy/redis
```

Aguarde os pods voltarem:

```bash
kubectl -n gitops-demo-services rollout status deploy/postgresql
kubectl -n gitops-demo-services rollout status deploy/rabbitmq
kubectl -n gitops-demo-services rollout status deploy/redis
```

Repita as validações do passo anterior. Os dados gravados em PostgreSQL, Redis e RabbitMQ devem continuar nos volumes persistentes.

## 9. Desenvolvimento local opcional

Para rodar a aplicação Flask localmente, crie um ambiente virtual e instale as dependências:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r src/requirements.txt
```

Exponha os backends com port-forward:

```bash
kubectl -n gitops-demo-services port-forward svc/postgresql 5432:5432
kubectl -n gitops-demo-services port-forward svc/rabbitmq 5672:5672
kubectl -n gitops-demo-services port-forward svc/redis 6379:6379
```

Em outro terminal:

```bash
export POSTGRES_HOST=127.0.0.1
export RABBITMQ_HOST=127.0.0.1
export REDIS_HOST=127.0.0.1
python src/app.py
```

Acesse `http://localhost:8080`.

## Limpeza

Remova as Applications do Argo CD:

```bash
kubectl delete -n argocd -f manifests/argocd
```

Remova os recursos sincronizados, se necessário:

```bash
kubectl delete namespace gitops-demo-app
kubectl delete namespace gitops-demo-services
```

Isso também remove os PVCs dos backends no namespace `gitops-demo-services`.

## Troubleshooting

- Se a aplicação iniciar antes dos backends, ela continua de pé. Ao clicar em um botao, o backend correspondente e inicializado novamente antes do envio.
- Se os pods ficarem em `Pending`, confira a `StorageClass` padrão:
  ```bash
  kubectl get storageclass
  kubectl describe pvc -n gitops-demo-services
  ```
- Testes realizados em WSL/Debian-13 com K3S 1.35.
