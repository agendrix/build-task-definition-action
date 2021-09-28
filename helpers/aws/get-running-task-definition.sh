#!/bin/sh
set -e

while test $# -gt 0; do
  case "$1" in
    (--cluster)
        cluster="$2"
        shift;
        shift;;
    (--service)
        service="$2"
        shift;
        shift;;
    (-h|--help|*)
        echo "Ask the ECS service for the ARN of its current running task definition."
        echo "options:"
        echo "--cluster Name of the cluster"
        echo "--service Name of the service"
        exit 1;;
  esac
done

if [ -z "${cluster}" ] || [ -z "${service}" ]; then
  echo "One or more options are not set."; exit 1
fi

aws ecs describe-services --cluster "${cluster}" --services "${service}" \
  | jq '.services[0].deployments' \
  | jq 'map(select(.desiredCount == .runningCount))' \
  | jq '.[0].taskDefinition' \
  | jq -r 'select(. != null)'
