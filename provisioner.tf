# NodePool の create before destroy を安全に実行するため NodePool の削除前に
# Node の drain(Kubernetes) を実施して Pod を新しい NodePool に移動します。
resource "null_resource" "node_pool_provisioner" {
  triggers = {
    project_id         = var.project_id
    cluster_name       = var.cluster_name
    location           = var.location
    node_pool_name     = random_id.node_pool_name.hex
    drain_interval_sec = var.drain_interval_sec
  }

  # Node Pool が 削除される際にスクリプトを実行して Drain を行います
  provisioner "local-exec" {
    command = <<-EOT
      ${path.module}/scripts/drain-nodes.sh \
        --project_id ${self.triggers.project_id} \
        --location ${self.triggers.location} \
        --cluster_name ${self.triggers.cluster_name} \
        --node_pool_name ${self.triggers.node_pool_name} \
        --drain_interval_sec ${self.triggers.drain_interval_sec}
    EOT
  }

  depends_on = [
    google_container_node_pool.node_pool,
    random_id.node_pool_name,
  ]

  lifecycle {
    create_before_destroy = true
  }
}
