# single-node-k8-bootstrap
This is a bash script to help bootstrap a single node K3s server, mainly for dev site setup

# Initialize a Ubuntu installation

Copy and run below.  Please note towards end of the execution, you will need to provide SSH Key so you can connect to the server using user@serverIP.  Root access will be disabled.
```
curl -sSL https://raw.githubusercontent.com/chassis-app/single-node-k8-bootstrap/refs/heads/main/01-UbuntuInit.sh -o 01-UbuntuInit.sh
chmod +x 01-UbuntuInit.sh
bash 01-UbuntuInit.sh
```
