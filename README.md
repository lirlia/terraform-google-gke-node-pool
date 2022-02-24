# Terraform GKE Node Pool Module

Terraform で NodePool の設定変更を行う場合、設定項目によっては NodePool の再作成が行われます。

この時、Terraform は Kubernetes 上のリソースを安全に退避せずに処理を行ってしまうため、この module では[自作のスクリプト](scripts/drain-nodes.sh) を利用して **NodePool の削除前に Node の Drain を実施して Pod の退避を行っています。**

NodePool が再作成される際のフローは以下のとおりです。

1. NodePool を新規作成
1. 旧 NodePool を Cordon & Drain
    - ここで Node 上の Pod が新しい NodePool に移動します
1. 旧 NodePool を削除

※[baozuo/terraform-google-gke-node-pool: A Terraform module to create GKE node pool featuring zero downtime during recreation](https://github.com/baozuo/terraform-google-gke-node-pool) を参考にしており、そこから一部改修＋機能追加しています。

## Requirements

以下の環境で動作を確認しています。

- Terraform 1.1.6
- Google Provider 4.11.0

また以下のコマンドが必要です。(権限含む)

- kubectl
- gcloud

## example

```terraform
module "nodepool_app" {
  source             = "this module path"
  project_id         = "YOUR-GCP-PROJECT-ID"
  prefix             = "YOUR-NODEPOOL-PREFIX"
  cluster_name       = "YOUR-CLUSTER-NAME"
```
