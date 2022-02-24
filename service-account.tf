resource "google_service_account" "node_default" {
  account_id = "${random_id.sa_name.hex}-node"
}

# NodePool を作成した際に同じ prefix の場合に
# ServiceAccount のバッティングが発生するためランダム文字列を作成します
resource "random_id" "sa_name" {
  byte_length = 2
  prefix      = format("%s-", var.prefix)
}

# Service Account
## https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster?hl=ja
## GKE では、サービス アカウントに少なくとも
## monitoring.viewer、monitoring.metricWriter、logging.logWriter、stackdriver.resourceMetadata.writer のロールが必要
locals {
  node_default_roles = [
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer"
  ]
}

resource "google_project_iam_member" "node_default_policy" {
  project  = var.project_id
  for_each = toset(local.node_default_roles)
  role     = each.value
  member   = "serviceAccount:${google_service_account.node_default.email}"
}

#
# Container Registry へのアクセス権限を付与します
#
# 複数の Container Registry に対してこの module を呼び出すごとに権限を与えると
# 大量の terraform state が作成されてしまうため、artifacts.${var.project_id}.appspot.com を満たす
# すべての GCS バケットへのアクセス権限を付与します
#
resource "google_project_iam_member" "container_registry_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.node_default.email}"

  # https://cloud.google.com/iam/docs/conditions-attribute-reference#resource-name
  # https://cloud.google.com/container-registry/docs/access-control#grant
  condition {
    title       = "read to container registry in google storage"
    description = "grant permission to access gcs which ends with 'artifacts.${var.project_id}.appspot.com'"
    expression  = <<-EOT
      resource.name.startsWith("projects/_/buckets/artifacts.${var.project_id}.appspot.com") ||
      resource.name.startsWith("projects/_/buckets/asia.artifacts.${var.project_id}.appspot.com") ||
      resource.name.startsWith("projects/_/buckets/us.artifacts.${var.project_id}.appspot.com") ||
      resource.name.startsWith("projects/_/buckets/eu.artifacts.${var.project_id}.appspot.com")
    EOT
  }
}
