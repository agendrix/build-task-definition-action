#!/bin/sh
set -e

get_task_definition() {
  task_name=$1

  # Thoses keys are returned by the Amazon ECS DescribeTaskDefinition, but are not valid fields when registering a new task definition
  keys_to_omit=".compatibilities, .taskDefinitionArn, .requiresAttributes, .revision, .status, .registeredBy, .registeredAt"

  returned_task_definition=$(aws ecs describe-task-definition --task-definition "${task_name}" | jq .taskDefinition | jq "del($keys_to_omit)")
  if [ -z "${returned_task_definition}" ]; then
    echo "ERROR: aws ecs describe-task-definition returned a bad value."; exit 1
  fi
}

set_outputs() {
  should_deploy=$1
  task_definition=$2
  running_stable_task_definition=$3

  echo "::set-output name=should_deploy::$should_deploy"

  output_path="/tmp/task-definition.$INPUT_SERVICE.json"
  echo "$task_definition" > "$output_path"
  echo "::set-output name=path::$output_path"

  if [ -n "$running_stable_task_definition" ]; then
    stable_output_path="/tmp/task-definition.stable.json"
    echo "$running_stable_task_definition" > "$stable_output_path"
    echo "::set-output name=current_stable_task_definition_path::$stable_output_path"
  fi
}

pretty_print_task_definition() {
  task_definition=$1
  task_definition=$(echo "$task_definition" | jq -S '.containerDefinitions[].environment |= sort_by(.name) | .containerDefinitions[].secrets |= sort_by(.name)')
  echo "$task_definition"
}

container_definitions=$(sed -e "s+<IMAGE>+$INPUT_IMAGE+g;" -e "s+<CLUSTER>+$INPUT_CLUSTER+g;" -e "s+<REGION>+$INPUT_REGION+g; "$INPUT_CONTAINER_DEFINITIONS_PATH")
container_definitions=$(
  echo "$container_definitions" | \
  jq '. | map(if has("portMappings") then .portMappings |= map(if .hostPort == null then .hostPort = .containerPort else . end) else . end)'
)

if [ -f "$INPUT_SECRETS_PATH" ]; then
  echo "Appending secrets for service $INPUT_SERVICE"
  container_definitions=$(echo "$container_definitions" | jq --slurpfile secrets "$INPUT_SECRETS_PATH" '(.[] | .secrets) = $secrets[]')
fi

get_task_definition "$(echo "${INPUT_CLUSTER}_${INPUT_SERVICE}" | tr - _)"
latest_task_definition=$returned_task_definition
new_task_definition=$(echo "$latest_task_definition" | jq --argjson container_defs "$container_definitions" '.containerDefinitions = $container_defs')

if [ -n "$CURRENT_STABLE_TASKDEF_ARN" ]; then
  # The variable has a trailing '\\n' - probably because it is stored as an environnement variable.
  get_task_definition "$(echo "${CURRENT_STABLE_TASKDEF_ARN}" | tr  -d '\n')"
  current_stable_taskdef="$returned_task_definition"

  current_tmp="$(mktemp)"; pretty_print_task_definition "$current_stable_taskdef" > "$current_tmp" 
  new_tmp="$(mktemp)"; pretty_print_task_definition "$new_task_definition" > "$new_tmp" 

  if cmp -s "$current_tmp" "$new_tmp"; then
    echo "The task definition has not changed. Deployment will be skipped."
    set_outputs "false" "$latest_task_definition" "$current_stable_taskdef"
    exit 0
  else
    echo "::group::Diff between the current running task definition and the new one"
    echo "Current task definition:                                           New task definition diff:"
    diff -y -t --left-column "$current_tmp" "$new_tmp" || true # true prevents exit code 1
    echo "::endgroup::"

    set_outputs "true" "$new_task_definition" "$current_stable_taskdef"
    exit 0
  fi
fi

set_outputs "true" "$new_task_definition" ""
