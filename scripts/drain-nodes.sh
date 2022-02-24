#!/bin/bash
# このスクリプトは Terraform の local-exec から呼ばれることを前提にしています
# また動作に gcloud / kubectl が必要となります
#
# このスクリプトは GKE NodePool を再作成する際に Node の Drain 処理を行います
# 具体的な流れについては以下のドキュメントを前提にしています
# https://cloud.google.com/kubernetes-engine/docs/tutorials/migrating-node-pool

set -o pipefail
set -o nounset
set -o errexit

function prefail() {
    echo "$1"
    exit 1
}

# 引数の取得
while [[ $# -gt 0 ]]; do
    case "$1" in
    --project_id)
        PROJECT_ID="$2"
        shift 2
        ;;
    --location)
        LOCATION="$2"
        shift 2
        ;;
    --cluster_name)
        CLUSTER_NAME="$2"
        shift 2
        ;;
    --node_pool_name)
        NODE_POOL_NAME="$2"
        NODE_POOL_PREFIX="${NODE_POOL_NAME%-*}"
        shift 2
        ;;
    --drain_interval_sec)
        DRAIN_INTERVAL_SEC="$2"
        shift 2
        ;;
    *)
        prefail "Unknown argument: $1"
        ;;
    esac
done

[ "${PROJECT_ID:-''}" == "" ] && prefail "project_id is not set"
[ "${LOCATION:-''}" == "" ] && prefail "location is not set"
[ "${CLUSTER_NAME:-''}" == "" ] && prefail "cluster_name is not set"
[ "${NODE_POOL_NAME:-''}" == "" ] && prefail "node_pool_name is not set"
[ "${DRAIN_INTERVAL_SEC:-''}" == "" ] && prefail "drain_interval_sec is not set"

# gcloud で使用する引数をロケーションごとに変更します
if [[ "$LOCATION" = *-[a-z] ]]; then
    location_filter="--zone $LOCATION"
else
    location_filter="--region $LOCATION"
fi

# GKE 接続用の credential を取得
gcloud container clusters get-credentials "$CLUSTER_NAME" $location_filter --project "$PROJECT_ID"

GCLOUD_NODEPOOL_CMD_ARGS=(
    $location_filter
    --cluster="$CLUSTER_NAME"
    --project="$PROJECT_ID"
)

old_node_pool="$(gcloud container node-pools list \
                    --filter="name~^$NODE_POOL_PREFIX-* AND name!=$NODE_POOL_NAME" \
                    --limit=1 \
                    --format='value(name)' \
                    ${GCLOUD_NODEPOOL_CMD_ARGS[@]})"

# 古い NodePool が存在しない場合は終了します
if [ -z "${old_node_pool}" ]; then
    echo "Node pool is not exists."
    exit 0
fi

# NodePool が作成された後、NodePool Status が Ready になるのを待ちます
node_status=""
while [ "$node_status" != "RUNNING" ]
do
    node_status="$(gcloud container node-pools describe $NODE_POOL_NAME \
                    --format='value(status)' \
                    ${GCLOUD_NODEPOOL_CMD_ARGS[@]})"

    echo "Waiting for the new node pool $NODE_POOL_NAME to be ready..."
    sleep 5
done

#
# 削除する NodePool が Drain 時に AutoScaling され
# Pod が古い NodePool に移動することを防ぐため AutoScaling 設定を無効化します。
#
# また GKE では同じクラスタに紐づく NodePool の操作は同時に行えないため
# gke-node-pool module が複数回呼び出されると並列に動作するためこのコマンドが
# 失敗することがあります。これを避けるため成功するまでループをします。
#
# ※gcloud コマンドの失敗時はエラーが発生するのでこのループだけ errexit を無効化しています
#
set +e
until gcloud container node-pools update "$old_node_pool" --no-enable-autoscaling "${GCLOUD_NODEPOOL_CMD_ARGS[@]}"
do
    echo "Waiting for the old node pool $old_node_pool to disable autoscaling..."
    sleep 20
done
set -e
echo "Disabled autoscaling for the $old_node_pool"

# 削除する NodePool の Node に対して Cordon を実行して Pod がスケジュールされないようにします
echo "Cordoning nodes... ($old_node_pool)"
kubectl get nodes -l "cloud.google.com/gke-nodepool=$old_node_pool" -o=name | xargs -I{} kubectl cordon {}

# 削除する NodePool の Node に対して Drain を実行して Pod を移動します
# 処理は 1 Node づつ行われます
echo "Draining nodes..."
for node in $(kubectl get nodes -l "cloud.google.com/gke-nodepool=$old_node_pool" -o=name); do
    echo "Draining node $node"
    kubectl drain --force --ignore-daemonsets --delete-emptydir-data "$node"
    # 次の Node を Drain するまで一定時間待ちます
    # すべての リソースに PodDisruptionBudget が設定されていれば DRAIN_INTERVAL_SEC は0で構いません
    sleep "$DRAIN_INTERVAL_SEC"
done
