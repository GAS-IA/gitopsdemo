# Instalação do Argo CD

Este guia instala o Argo CD no namespace `argocd` usando os manifests oficiais do projeto. Ele é suficiente para executar a demo GitOps deste repositório.

Referência oficial:

- https://argo-cd.readthedocs.io/en/stable/getting_started/

## Pré-requisitos

- Cluster Kubernetes acessível.
- `kubectl` apontando para o cluster correto.
- Permissão para criar namespaces, CRDs, Deployments, Services, Roles e ClusterRoles.

Confirme o contexto atual antes de instalar:

```bash
kubectl config current-context
kubectl get nodes
```

## 1. Criar o namespace

```bash
kubectl create namespace argocd
```

Se o namespace já existir, o comando falha sem causar dano. Nesse caso, siga para o próximo passo.

## 2. Instalar o Argo CD

```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Esse manifesto instala os componentes centrais do Argo CD, incluindo server, repo-server, application-controller, redis, dex e CRDs.

O `--server-side` evita problemas com CRDs grandes que podem ultrapassar o limite de anotações do `kubectl apply` client-side. O `--force-conflicts` e adequado para uma instalação nova.

## 3. Aguardar os pods

```bash
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
kubectl get pods -n argocd
```

Todos os pods principais devem ficar em `Running`.

## 4. Acessar a UI

O usuario inicial é `admin`. Obtenha a senha:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

Então rode:

```bash
kubectl -n argocd port-forward svc/argocd-server 8081:443 --address 0.0.0.0
```

E acesse:

```text
https://localhost:8081
```

O navegador pode alertar sobre certificado local. Para esta demo, isso é esperado quando se usa `port-forward`.

Depois do primeiro login, troque a senha do usuário `admin` pela UI ou pela CLI.

## 5. Instalar a CLI opcional

A CLI `argocd` não é obrigatória para a demo, mas ajuda a inspecionar e sincronizar Applications. Consulte o método adequado para o seu sistema operacional na documentação oficial:

<https://argo-cd.readthedocs.io/en/stable/cli_installation/>

Depois de instalar a CLI, faca login usando o port-forward ativo:

```bash
argocd login localhost:8081
```

Use `admin` e a senha inicial obtida no passo anterior.

## 6. Validar a instalação

Via Kubernetes:

```bash
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

Via CLI:

```bash
argocd version
argocd app list
```

Se esses comandos responderem, o Argo CD está pronto para receber os manifests em `manifests/argocd`.

## 7. Próximo passo da demo

Depois que o Argo CD estiver instalado, aplique o bootstrap da demo:

```bash
kubectl apply -n argocd -f manifests/argocd
```

Esse passo cria o `AppProject` e as `Applications` que sincronizam `manifests/services` e `manifests/app`.

## Limpeza

Para remover o Argo CD instalado por este guia:

```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

Antes de remover o namespace, confirme se não há outros recursos importantes gerenciados por essa instalação.
