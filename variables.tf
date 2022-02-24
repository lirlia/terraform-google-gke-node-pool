variable "project_id" {
  description = "NodePool を作成する GCP プロジェクトの ID です"
  type        = string
}

variable "prefix" {
  type        = string
  description = "NodePool のリソースに使用する prefix です"
}

variable "cluster_name" {
  type        = string
  description = "NodePool が参加する GKE クラスタ名です"
}

variable "gke_version" {
  type        = string
  description = <<-EOT
    NodePool の GKE version です。
    このパラメータを使用する場合は auto_upgrade を false にしてください。
  EOT
  default     = null
}

variable "location" {
  type        = string
  description = "NodePool を作成する Location です"
  default     = "asia-northeast1"
}

variable "node_locations" {
  type        = list(string)
  description = "Node を起動する Location です"
  default = [
    "asia-northeast1-a",
    "asia-northeast1-b",
    "asia-northeast1-c",
  ]
}

# initial_node の初期値が0のためmin未満で起動するとAutoscalerが効かなくなるため
# min_node_count ≦ initial_node_count ≦ max_node_count になるように設定してください
variable "initial_node_count" {
  type        = number
  description = "NodePool の最初に起動するノード数です"
  default     = 1
}

variable "labels" {
  type        = map(string)
  description = "NodePool に付与する label を key-value 形式で指定してください"
  default     = {}
}

variable "tags" {
  type        = list(string)
  description = "NodePool に付与する tag です。"
  default     = []
}

variable "config" {
  type        = map(string)
  description = "NodePool に付与する様々な設定を key-value 形式で指定してください"
  default     = {}
}

variable "oauth_scopes" {
  type        = list(string)
  description = "NodePool に許可したい OAuth Scope です"

  default = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/trace.append"
  ]
}

variable "taints" {
  type = list(object({
    key    = string,
    value  = string,
    effect = string
  }))
  description = "NodePool に付与する Taint です"
  default     = []
}

# これ以降の変数は Node を Drain するスクリプトで用いられます
variable "drain_interval_sec" {
  type        = number
  description = "Node を Drain した後に、次の Node を Drain するまでのインターバル(秒)です"
  default     = 60
}
