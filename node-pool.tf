resource "google_container_node_pool" "node_pool" {
  name               = random_id.node_pool_name.hex
  project            = var.project_id
  location           = var.location
  cluster            = var.cluster_name
  version            = var.gke_version
  initial_node_count = var.initial_node_count
  node_locations     = var.node_locations

  lifecycle {
    ignore_changes        = [initial_node_count]
    create_before_destroy = true
  }

  # initial_node の初期値が0のためmin未満で起動するとAutoscalerが効かなくなるため
  # min ≦ initial_node_count ≦ max になるように設定してください
  autoscaling {
    min_node_count = lookup(var.config, "min_node_count", 1)
    max_node_count = lookup(var.config, "max_node_count", 1)
  }

  management {
    # https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-repair?hl=ja
    # GKE でクラスタ内の各ノードのヘルス状態が定期的にチェックされます。
    # ノードが長期にわたって連続してヘルスチェックに失敗すると、GKE はそのノードの修復プロセスを開始します。
    auto_repair = lookup(var.config, "auto_repair", true)

    # https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-upgrades?hl=ja
    # ノードの自動アップグレードを有効にするとコントロールプレーンが更新されるときに、
    # クラスタのコントロール プレーン（マスター）のバージョンを使用してクラスタ内のノードが最新の状態に維持されるようになります。
    auto_upgrade = lookup(var.config, "auto_upgrade", true)
  }

  upgrade_settings {
    max_surge       = lookup(var.config, "max_surge", 1)
    max_unavailable = lookup(var.config, "max_unavailable", 0)
  }

  node_config {
    machine_type    = lookup(var.config, "machine_type", "n2-standard-2")
    disk_type       = lookup(var.config, "disk_type", "pd-standard")
    disk_size_gb    = lookup(var.config, "disk_size_gb", 100)
    preemptible     = lookup(var.config, "preemptible", false)
    service_account = google_service_account.node_default.email
    labels          = var.labels
    tags            = var.tags
    oauth_scopes    = var.oauth_scopes

    dynamic "taint" {
      for_each = var.taints
      content {
        effect = taint.value.effect
        key    = taint.value.key
        value  = taint.value.value
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# create_before_destroy によって NodePool を削除前に作成する場合、
# 名前のバッティングが発生するため NodePool 名にランダムな文字列を含めます
resource "random_id" "node_pool_name" {
  byte_length = 2
  prefix      = format("%s-pool-", var.prefix)

  # 以下の変数が変更された場合は名前を再作成して NodePool を作り直します
  # NodePool が再作成される設定変更はここに追記していってください
  keepers = {
    gke_version    = var.gke_version
    disk_size_gb   = lookup(var.config, "disk_size_gb", "")
    disk_type      = lookup(var.config, "disk_type", "")
    machine_type   = lookup(var.config, "machine_type", "")
    preemptible    = lookup(var.config, "preemptible", "")
    labels         = join(",", sort(concat(keys(var.labels), values(var.labels))))
    tags           = join(",", sort(concat(var.tags)))
    oauth_scopes   = join(",", sort(concat(var.oauth_scopes)))
    node_locations = join(",", sort(var.node_locations))
  }
}
