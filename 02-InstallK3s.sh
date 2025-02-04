#!/bin/bash

# Set variables for better readability and maintainability
K3S_VERSION="v1.31.5+k3s1" # Example version.  Pin to a specific version for production.
TRAEFIK_VERSION="v3.3.2" # Example version
ARGOCD_VERSION="v2.14.1" # Example version

# 1. Install K3s without Traefik
echo "Installing K3s ${K3S_VERSION} cluster..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" INSTALL_K3S_EXEC="server --disable traefik" sh -s -

# 2. Configure kubeconfig
echo "Setting up kubeconfig..."
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$USER:$USER" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
# Use `kubectl config set-context` for better context management
kubectl config set-context --current --kubeconfig "$HOME/.kube/config" --server="https://$(kubectl config view --kubeconfig "$HOME/.kube/config" -o jsonpath='{.clusters[0].cluster.server}')"
export KUBECONFIG="$HOME/.kube/config"

# 3. Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4. Install Traefik using Helm
echo "Installing Traefik ${TRAEFIK_VERSION} using Helm..."
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik -n kube-system --version "${TRAEFIK_VERSION}"

# 5. Wait for Traefik to be ready with retry logic
echo "Waiting for Traefik to be ready..."
max_retries=20
retry_count=0
while [[ $retry_count -lt $max_retries ]]; do
  if kubectl rollout status deployment/traefik -n kube-system --watch --timeout=10s; then
    echo "Traefik is ready."
    break
  else
    echo "Traefik not yet ready, retrying in 5 seconds..."
    sleep 5
    retry_count=$((retry_count + 1))
  fi
done

if [[ $retry_count -eq $max_retries ]]; then
  echo "Traefik deployment timed out. Check logs for errors."
  exit 1
fi

# 6. Install Argo CD
echo "Installing Argo CD ${ARGOCD_VERSION}..."
kubectl create namespace argocd

# Patch the manifest to set insecure to true (for demonstration purposes only - NOT RECOMMENDED FOR PRODUCTION)
manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
patched_manifest=$(curl -s "$manifest_url" | sed 's/value: "false"/value: "true"/g' | sed 's/name: insecure/name: argocd-server.insecure/g')

# Apply the patched manifest
echo "$patched_manifest" | kubectl apply -n argocd -f -

# 7. Wait for Argo CD to be ready with retry logic
echo "Waiting for Argo CD to be ready..."

max_retries=20
retry_count=0

while [[ $retry_count -lt $max_retries ]]; do
    if kubectl rollout status deployment/argocd-server -n argocd --watch --timeout=10s; then
        echo "Argo CD is ready."
        break
    else
        echo "Argo CD not yet ready, retrying in 5 seconds..."
        sleep 5
        retry_count=$((retry_count + 1))
    fi
done


if [[ $retry_count -eq $max_retries ]]; then
  echo "Argo CD deployment timed out. Check logs for errors."
  exit 1
fi


# Important: For production, remove the insecure setting and configure TLS.
echo "Argo CD is ready. Remember to remove the insecure setting for production and configure TLS."
