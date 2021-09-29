# Build Task Definition from ECS Service

Build a task-definition from merging a given container-definitions JSON file into the task-definition of a running service on ECS.

See [action.yml](./action.yml) for the list of `inputs` and `outputs`.

## Example usage

```yaml
deploy-app-cache-job:
  name: Deploy app & cache
  runs-on: ubuntu-latest

  strategy:
    matrix:
      service: [app, cache]

  steps:
    - name: Checkout
      uses: actions/checkout@v2

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Create ${{ matrix.service }} task definition
      id: task-definition
      uses: agendrix/build-task-definition-action@v1.0.0
      with:
        cluster: ${{ env.CLUSTER_NAME }}
        service: ${{ matrix.service }}
        container_definitions_path: container-definitions/${{ matrix.service }}.json
```
