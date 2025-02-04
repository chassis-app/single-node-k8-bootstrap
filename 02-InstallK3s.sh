#!/bin/bash

# Set variables
K3S_VERSION="v1.31.5+k3s1" # Example version - pin for production
TRAEFIK_VERSION="v34.2" # Example version - pin for production. v3 is a major change and may require different configurations.
ARGOCD_VERSION="v7.7.23" # Example version - pin for production.  v7 is a major change and may require different configurations.

# Ask the user for the domain
read -p "Enter the base domain (e.g., app.com): " BASE_DOMAIN

# Construct the Traefik subdomain
TRAEFIK_SUBDOMAIN="t.${BASE_DOMAIN}"

# 1. Install K3s without Traefik
echo "Installing K3s ${K3S_VERSION} cluster..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644" sh -s -

# 2. Configure kubeconfig
echo "Setting up kubeconfig..."
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$USER:$USER" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
kubectl config set-context --current --kubeconfig "$HOME/.kube/config" --server="https://$(kubectl config view --kubeconfig "$HOME/.kube/config" -o jsonpath='{.clusters[0].cluster.server}')"
export KUBECONFIG="$HOME/.kube/config"

# 3. Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4. Install Traefik using Helm with values.yaml
echo "Installing Traefik ${TRAEFIK_VERSION} using Helm..."

cat <<EOF > traefik-values.yaml
global:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: traefik # Ensure this matches your IngressClass (can be traefik-external if needed)
    hosts:
      - host: ${TRAEFIK_SUBDOMAIN}
        tls: # Uncomment to enable TLS (highly recommended for production)
          secretName: traefik-cert # Create a TLS certificate secret

ports:
  web:
    port: 80
  websecure:
    port: 443

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

service:
  enabled: true
  type: NodePort

EOF

helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik -n kube-system --version "${TRAEFIK_VERSION}" -f traefik-values.yaml

# 5. Wait for Traefik to be ready
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
  echo "Traefik deployment timed out. Check logs for errors: kubectl logs -n kube-system deployment/traefik"
  exit 1
fi

# Get the NodePort for Traefik's web service
TRAEFIK_NODEPORT=$(kubectl get service traefik -n kube-system -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}')

# 6. Install Argo CD
echo "Installing Argo CD ${ARGOCD_VERSION}..."
kubectl create namespace argocd

# Patch the manifest to set insecure to true (NOT RECOMMENDED FOR PRODUCTION)
manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" # Use the stable manifest URL
patched_manifest=$(curl -s "$manifest_url" | sed 's/value: "false"/value: "true"/g' | sed 's/name: insecure/name: argocd-server.insecure/g')

# Apply the patched manifest
echo "$patched_manifest" | kubectl apply -n argocd -f -

# 7. Wait for Argo CD to be ready
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
  echo "Argo CD deployment timed out. Check logs for errors: kubectl logs -n argocd deployment/argocd-server"
  exit 1
fi


echo "Traefik dashboard should be accessible at: http://${TRAEFIK_SUBDOMAIN}:${TRAEFIK_NODEPORT}"
echo "Remember to configure your DNS records to point ${TRAEFIK_SUBDOMAIN} to your K3s server's public IP."
echo "Also, you'll need to configure your node's firewall to forward port ${TRAEFIK_NODEPORT} to your K3s server."
echo "Argo CD is installed in the argocd namespace."
echo "To access Argo CD, you'll need to port-forward the argocd-server service:"
echo "kubectl port-forward -n argocd service/argocd-server 8080:8080"
echo "Then, you can access it at http://localhost:8080"
