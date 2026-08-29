terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

# Generate cryptographically secure cluster join token
resource "random_password" "k3s_cluster_token" {
  length  = 32
  special = false
}

# 1. Bootstrap K3s Control Plane Node
resource "null_resource" "k3s_control_plane_bootstrap" {
  triggers = {
    control_plane_ip = var.k8s_control_plane_ip
    k3s_version      = var.k3s_version
    token            = random_password.k3s_cluster_token.result
  }

  provisioner "local-exec" {
    command = <<EOT
      echo '===> Waiting for Control Plane Node ${var.k8s_control_plane_ip} SSH reachability...'
      for i in $(seq 1 30); do
        ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -o ConnectTimeout=3 -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_control_plane_ip} "echo ready" 2>/dev/null && break || sleep 2
      done

      echo '===> Initializing K3s Control Plane on ${var.k8s_control_plane_ip}...'
      ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_control_plane_ip} \
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${random_password.k3s_cluster_token.result}' sh -s - server \
          --cluster-cidr='${var.cluster_cidr}' \
          --service-cidr='${var.service_cidr}' \
          --cluster-dns='${var.cluster_dns}' \
          --tls-san='${var.k8s_control_plane_ip}' \
          --tls-san='${var.nested_hypervisor_ip}' \
          --tls-san='127.0.0.1' \
          --write-kubeconfig-mode='0644' \
          --disable=traefik"

      echo '===> Waiting for Control Plane Node to become Ready...'
      for i in $(seq 1 30); do
        READY=$(ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_control_plane_ip} "kubectl get nodes --no-headers 2>/dev/null | grep -w Ready | wc -l" || echo 0)
        if [ "$READY" -ge 1 ]; then
          echo '===> Control Plane Node is Ready!'
          break
        fi
        sleep 2
      done
    EOT
  }
}

# 2. Join Worker Nodes to K3s Cluster
resource "null_resource" "k3s_worker_bootstrap" {
  count      = length(var.k8s_worker_ips)
  depends_on = [null_resource.k3s_control_plane_bootstrap]

  triggers = {
    worker_ip   = var.k8s_worker_ips[count.index]
    k3s_version = var.k3s_version
    token       = random_password.k3s_cluster_token.result
  }

  provisioner "local-exec" {
    command = <<EOT
      echo '===> Waiting for Worker Node ${var.k8s_worker_ips[count.index]} SSH reachability...'
      for i in $(seq 1 30); do
        ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -o ConnectTimeout=3 -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_worker_ips[count.index]} "echo ready" 2>/dev/null && break || sleep 2
      done

      echo '===> Joining Worker Node ${var.k8s_worker_ips[count.index]} to K3s cluster...'
      ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_worker_ips[count.index]} \
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_URL='https://${var.k8s_control_plane_ip}:6443' K3S_TOKEN='${random_password.k3s_cluster_token.result}' sh -"
    EOT
  }
}

# 3. Extract and Configure Kubeconfig for Workstation Access
resource "null_resource" "extract_kubeconfig" {
  depends_on = [
    null_resource.k3s_control_plane_bootstrap,
    null_resource.k3s_worker_bootstrap
  ]

  triggers = {
    control_plane_ip = var.k8s_control_plane_ip
  }

  provisioner "local-exec" {
    command = <<EOT
      echo '===> Fetching cluster kubeconfig from control plane...'
      mkdir -p ${path.module}/.kube
      ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_control_plane_ip} \
        "sudo cat /etc/rancher/k3s/k3s.yaml" > ${path.module}/.kube/k3s-raw.yaml

      # Generate workstation tunnel kubeconfig (server pointing to localhost:6443)
      sed "s/127.0.0.1:6443/127.0.0.1:6443/g" ${path.module}/.kube/k3s-raw.yaml > ${path.module}/kubeconfig.yaml
      chmod 0600 ${path.module}/kubeconfig.yaml

      # Generate direct internal kubeconfig (server pointing to control plane IP)
      sed "s/127.0.0.1:6443/${var.k8s_control_plane_ip}:6443/g" ${path.module}/.kube/k3s-raw.yaml > ${path.module}/kubeconfig-direct.yaml
      chmod 0600 ${path.module}/kubeconfig-direct.yaml
      echo '===> Workstation kubeconfig written to ${path.module}/kubeconfig.yaml'
    EOT
  }
}

# 4. Deploy Core Addons / Workload Verification Checks
resource "null_resource" "verify_k8s_cluster" {
  depends_on = [null_resource.extract_kubeconfig]

  triggers = {
    control_plane_ip = var.k8s_control_plane_ip
    worker_count     = length(var.k8s_worker_ips)
  }

  provisioner "local-exec" {
    command = <<EOT
      echo '===> Verifying Kubernetes Cluster Node Readiness...'
      ssh -o UserKnownHostsFile=${var.stage2_known_hosts_path} -o StrictHostKeyChecking=yes -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_control_plane_ip} \
        "kubectl get nodes -o wide && kubectl get pods -A"
    EOT
  }
}
