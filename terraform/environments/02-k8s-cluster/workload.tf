# Stage 2 Workload Deployment & Ingress Provisioning (workload.tf)

# 1. Deploy Dynamic Cluster Monitoring Dashboard to Worker Node & Configure Hypervisor Ingress
resource "null_resource" "deploy_dashboard_workload" {
  depends_on = [libvirt_domain.k8s_worker]

  triggers = {
    worker_ip      = var.k8s_worker_ips[0]
    dashboard_hash = filemd5("${path.module}/manifests/dashboard.py")
  }

  # Deploy Dashboard Service on Worker Node via Jump Host and Configure Hypervisor NAT Forwarding
  provisioner "local-exec" {
    command = <<EOT
      echo '===> Uploading Dashboard Service to Worker Node ${var.k8s_worker_ips[0]}...'
      scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${path.module}/manifests/dashboard.py ${var.nested_hypervisor_user}@${var.k8s_worker_ips[0]}:/tmp/dashboard.py

      echo '===> Installing Dashboard Systemd Service on Worker Node ${var.k8s_worker_ips[0]}...'
      ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_worker_ips[0]} "sudo cp /tmp/dashboard.py /usr/local/bin/dashboard.py && sudo chmod +x /usr/local/bin/dashboard.py && sudo systemctl stop nginx 2>/dev/null || true"

      echo '===> Creating Systemd Unit on Worker Node ${var.k8s_worker_ips[0]}...'
      ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} -J ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} ${var.nested_hypervisor_user}@${var.k8s_worker_ips[0]} "printf '[Unit]\nDescription=Dynamic K8s Dashboard\nAfter=network.target\n\n[Service]\nExecStart=/usr/bin/python3 /usr/local/bin/dashboard.py\nRestart=always\nUser=root\n\n[Install]\nWantedBy=multi-user.target\n' | sudo tee /etc/systemd/system/dashboard.service > /dev/null && sudo systemctl daemon-reload && sudo systemctl enable --now dashboard"

      echo '===> Configuring Stage 1 Hypervisor Port Forwarding (8080 -> ${var.k8s_worker_ips[0]}:30080)...'
      ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ${var.nested_hypervisor_user}@${var.nested_hypervisor_ip} "sudo sysctl -w net.ipv4.ip_forward=1 && sudo iptables -t nat -F PREROUTING || true && sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination ${var.k8s_worker_ips[0]}:30080 && sudo iptables -I FORWARD 1 -p tcp -d ${var.k8s_worker_ips[0]} --dport 30080 -j ACCEPT"
    EOT
  }
}
