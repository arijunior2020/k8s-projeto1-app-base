#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"
BACKEND_REPO="${BACKEND_REPO:-arimateiajunior/projeto-backend}"
DATABASE_REPO="${DATABASE_REPO:-arimateiajunior/projeto-database}"
BACKEND_IMAGE="${BACKEND_IMAGE:-${BACKEND_REPO}:${IMAGE_TAG}}"
DATABASE_IMAGE="${DATABASE_IMAGE:-${DATABASE_REPO}:${IMAGE_TAG}}"
K8S_SECRET_NAME="app-secrets"
K8S_ENV_FILE="${K8S_ENV_FILE:-${ROOT_DIR}/.env.k8s}"
NAMESPACE="${NAMESPACE:-default}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-240s}"
PUSH_IMAGES=true

usage() {
  cat <<EOF
Uso: ./script.sh [opcoes]

Opcoes:
  --push      Forca push das imagens para o Docker Hub (padrao)
  --no-push   Nao faz push das imagens
  -h, --help  Mostra esta ajuda

Variaveis opcionais:
  IMAGE_TAG       (padrao: ${IMAGE_TAG})
  BACKEND_REPO    (padrao: ${BACKEND_REPO})
  DATABASE_REPO   (padrao: ${DATABASE_REPO})
  BACKEND_IMAGE   (sobrescreve BACKEND_REPO+IMAGE_TAG)
  DATABASE_IMAGE  (sobrescreve DATABASE_REPO+IMAGE_TAG)
  K8S_ENV_FILE    (padrao: ${K8S_ENV_FILE})
  NAMESPACE       (padrao: ${NAMESPACE})
  WAIT_TIMEOUT    (padrao: ${WAIT_TIMEOUT})
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Erro: comando obrigatorio nao encontrado: $1" >&2
    exit 1
  fi
}

for arg in "$@"; do
  case "$arg" in
    --push)
      PUSH_IMAGES=true
      ;;
    --no-push)
      PUSH_IMAGES=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Erro: opcao invalida: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd docker
require_cmd kubectl
require_cmd minikube

if [[ ! -f "${ROOT_DIR}/deployment.yml" || ! -f "${ROOT_DIR}/service.yml" ]]; then
  echo "Erro: deployment.yml e/ou service.yml nao encontrados em ${ROOT_DIR}" >&2
  exit 1
fi

if [[ ! -f "${K8S_ENV_FILE}" ]]; then
  echo "Erro: arquivo de segredos nao encontrado: ${K8S_ENV_FILE}" >&2
  echo "Crie ${ROOT_DIR}/.env.k8s com base em ${ROOT_DIR}/.env.k8s.example" >&2
  exit 1
fi

echo "Verificando status do Minikube..."
MINIKUBE_STATUS="$(minikube status --format='{{.Host}}' 2>/dev/null || true)"
if [[ "${MINIKUBE_STATUS}" != "Running" ]]; then
  echo "Minikube nao esta rodando. Iniciando..."
  minikube start
fi

if [[ "${NAMESPACE}" != "default" ]]; then
  kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"
fi

echo "Tag da release: ${IMAGE_TAG}"
echo "Build da imagem do backend: ${BACKEND_IMAGE}"
docker build -t "${BACKEND_IMAGE}" -f "${ROOT_DIR}/backend/dockerfile" "${ROOT_DIR}/backend"

echo "Build da imagem do banco: ${DATABASE_IMAGE}"
docker build -t "${DATABASE_IMAGE}" -f "${ROOT_DIR}/database/dockerfile" "${ROOT_DIR}/database"

echo "Carregando imagens no Minikube..."
minikube image load "${BACKEND_IMAGE}"
minikube image load "${DATABASE_IMAGE}"

if [[ "${PUSH_IMAGES}" == true ]]; then
  echo "Fazendo push das imagens para o Docker Hub..."
  docker push "${BACKEND_IMAGE}"
  docker push "${DATABASE_IMAGE}"
fi

echo "Aplicando manifests no namespace ${NAMESPACE}..."
echo "Aplicando Secret ${K8S_SECRET_NAME}..."
kubectl create secret generic "${K8S_SECRET_NAME}" \
  -n "${NAMESPACE}" \
  --from-env-file="${K8S_ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n "${NAMESPACE}" -f "${ROOT_DIR}/deployment.yml"
kubectl apply -n "${NAMESPACE}" -f "${ROOT_DIR}/service.yml"

echo "Atualizando deployments para as novas tags..."
kubectl set image deployment/mysql mysql="${DATABASE_IMAGE}" -n "${NAMESPACE}"
kubectl set image deployment/backend backend="${BACKEND_IMAGE}" -n "${NAMESPACE}"

echo "Aguardando deployments ficarem prontos..."
kubectl rollout status deployment/mysql -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"

echo "Recursos criados:"
kubectl get pods,svc,pvc -n "${NAMESPACE}"
kubectl get pv

BACKEND_URL="$(minikube service backend -n "${NAMESPACE}" --url 2>/dev/null || true)"
if [[ -n "${BACKEND_URL}" ]]; then
  echo "Backend disponivel em: ${BACKEND_URL}"
  echo "Teste frontend local: http://127.0.0.1:5500/frontend/index.html?api=${BACKEND_URL}"
fi
