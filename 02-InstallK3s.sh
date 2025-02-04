# 5. Install K3s without Traefik
echo "Installing K3s cluster..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" sh -s -

# 6. Configure kubeconfig
echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube # Use $HOME
cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config # Use $HOME
sudo chmod 666 /etc/rancher/k3s/k3s.yaml
chown 400 $HOME/.kube/config
sed -i 's/127.0.0.1/kubernetes.default.svc.cluster.local/' $HOME/.kube/config # Use $HOME
chown -R $USER:$USER $HOME/.kube # Use $HOME and $USER
chmod 600 $HOME/.kube/config # Use $HOME

# 7. Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 8. Install Traefik using Helm
echo "Installing Traefik using Helm..."
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik -n kube-system

# 9. Install Argo CD
echo "Installing Argo CD..."
export KUBECONFIG=$HOME/.kube/config # Use $HOME
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "\n\e[32mInstallation complete!\e[0m"
echo "Argo CD admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
