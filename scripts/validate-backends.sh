#!/usr/bin/env bash
set -euo pipefail

SERVICES_NAMESPACE="${SERVICES_NAMESPACE:-gitops-demo-services}"
POSTGRES_DEPLOYMENT="${POSTGRES_DEPLOYMENT:-postgresql}"
RABBITMQ_DEPLOYMENT="${RABBITMQ_DEPLOYMENT:-rabbitmq}"
REDIS_DEPLOYMENT="${REDIS_DEPLOYMENT:-redis}"
POSTGRES_USER="${POSTGRES_USER:-gitops_demo}"
POSTGRES_DB="${POSTGRES_DB:-incidents}"
REDIS_IDS_KEY="${REDIS_IDS_KEY:-incident_submissions:ids}"


section() {
  printf '\n== %s ==\n' "$1"
}


require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}


run() {
  printf '+ %s\n' "$*"
  "$@"
}


run_kubectl() {
  run kubectl -n "$SERVICES_NAMESPACE" "$@"
}


main() {
  require_command kubectl

  #section "Cluster resources"
  #run_kubectl get pods,svc,pvc

  section "PostgreSQL latest incident submissions"
  run_kubectl exec "deploy/${POSTGRES_DEPLOYMENT}" -- \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      -c "select id, title, service_name, severity, submitted_at from incident_submissions order by submitted_at desc limit 5;"

  section "RabbitMQ queues"
  run_kubectl exec "deploy/${RABBITMQ_DEPLOYMENT}" -- \
    rabbitmqctl list_queues name messages durable

  section "Redis incident count"
  run_kubectl exec "deploy/${REDIS_DEPLOYMENT}" -- \
    sh -c "redis-cli -a \"\$REDIS_PASSWORD\" llen ${REDIS_IDS_KEY}"

  section "Redis latest incident IDs"
  run_kubectl exec "deploy/${REDIS_DEPLOYMENT}" -- \
    sh -c "redis-cli -a \"\$REDIS_PASSWORD\" lrange ${REDIS_IDS_KEY} 0 4"
}


main "$@"
