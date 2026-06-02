# Verifique os recursos no cluster
`kubectl get nodes`
`kubectl get namespaces`
`kubectl -n argocd get all,cm,secrets`

# Acesse o ArgoCD pelo navegador
`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"|base64 -d && echo`
`kubectl -n argocd port-forward svc/argocd-server 10443:443 --address 0.0.0.0`

# Acesse localhost:10443 no navegador usando admin e a senha apresentada

# Veja as principais configurações do ArgoCD
- Settings:
    - Cluster
    - Repository
    - Project

# Aplique os manifestos de configuração
`kubectl -n argocd apply -f manifests/argocd/01-app-project.yaml`
`kubectl -n argocd apply -f manifests/argocd/02-repository.yaml`
- Mostrar as mudanças em Settings > Project/Repository

# Analise os manifestos em services
- Antes de aplicar os serviços, veja os manifestos e a lista de namespaces no cluster.
`kubectl -n argocd apply -f manifests/argocd/03-application-services.yaml`
- Verifique o novo namespace criado e os recuros nele.
`kubectl get namespaces`
`kubectl -n gitops-demo-services get all,cm,secret`
- Verifique o equivalente na aplicação gitops-demo-service pela interface web.

# Analise os manifestos em app
- Antes de aplicar os serviços, veja os manifestos e a lista de namespaces no cluster.
`kubectl -n argocd apply -f manifests/argocd/04-application-app.yaml`
- Verifique o novo namespace criado e os recuros nele.
`kubectl get namespaces`
`kubectl -n gitops-demo-app get all,cm,secret`
- Verifique o equivalente na aplicação gitops-demo-app pela interface web.

# Acesse a aplicação pela interface web
`kubectl -n gitops-demo-app port-forward svc/gitops-demo-app 8080:8080 --address 0.0.0.0`
- Faça alguns testes e rode o script para comprovar.

# Realize uma mudança
- Primeiro da forma errada pelo próprio ArgoCD.
- Depois da forma certa pelos manifestos.

# Verifique as actions
- Realize uma mudança no código e veja a execução

# Remova tudo
`kubectl -n argocd delete applications`
`kubectl -n argocd delete appproj`
`kubectl -n argocd delete secret`
