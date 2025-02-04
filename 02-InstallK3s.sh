# 5. Install K3s without Traefik
echo "Installing K3s cluster..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" sh -s -

# 6. Configure kubeconfig
echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chmod 666 /etc/rancher/k3s/k3s.yaml
sudo chown 400 $HOME/.kube/config
sed -i 's/127.0.0.1/kubernetes.default.svc.cluster.local/' $HOME/.kube/config
sudo chown -R $USER:$USER $HOME/.kube
sudo chmod 600 $HOME/.kube/config

# 7. Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 8. Install Traefik using Helm
echo "Installing Traefik using Helm..."
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik -n kube-system

# Wait for Traefik to be ready
echo "Waiting for Traefik to be ready..."
elapsed_time=0
while ! kubectl get pods -n kube-system | grep traefik | grep Running > /dev/null; do
  sleep 1
  elapsed_time=$((elapsed_time + 1))
  printf "\rTraefik initializing... %ds elapsed" "$elapsed_time"  # \r for same-line update
done
echo ""  # Add a newline after the loop
echo "Traefik is ready."

# 9. Install Argo CD
echo "Installing Argo CD..."
export KUBECONFIG=$HOME/.kube/config
kubectl create namespace argocd

# Patch the manifest to set insecure to true
manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
patched_manifest=$(curl -s "$manifest_url" | sed 's/value: "false"/value: "true"/g' | sed 's/name: insecure/name: argocd-server.insecure/g')

# Apply the patched manifest
echo "$patched_manifest" | kubectl apply -n argocd -f -

# Wait for Argo CD to be ready
echo "Waiting for Argo CD to be ready..."
elapsed_time=0

while ! kubectl get pods -n argocd | grep argocd-server | grep Running > /dev/null; do
  sleep 1
  elapsed_time=$((elapsed_time + 1))
  printf "\rArgo CD pod initializing... %ds elapsed" "$elapsed_time"
done

while ! kubectl get service argocd-server -n argocd > /dev/null 2>&1; do
  sleep 1
  elapsed_time=$((elapsed_time + 1))
  printf "\rArgo CD service not yet available... %ds elapsed" "$elapsed_time"
done

while ! curl --fail --insecure https://$(kubectl get service argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') 2>/dev/null; do
    sleep 1
    elapsed_time=$((elapsed_time + 1))
    printf "\rArgo CD server not yet responding... %ds elapsed" "$elapsed_time"
done


echo "" # Add a newline after the loop
echo "Argo CD is ready."
