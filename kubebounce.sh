deploys=`microk8s kubectl -n $1 get deployments | tail -n +2 | cut -d ' ' -f 1`
for deploy in $deploys; do
  microk8s kubectl -n $1 rollout restart deployments/$deploy
done
