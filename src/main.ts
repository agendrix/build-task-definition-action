import * as core from "@actions/core";
import { exec } from "@actions/exec";
import * as path from "path";
import { validateRequiredInputs } from "../helpers/action/validateRequiredInputs";

async function run() {
  try {
    validateRequiredInputs([
      "cluster",
      "service",
      "container_definitions_path"
    ]);

    const cluster = core.getInput("cluster", { required: true });
    const service = core.getInput("service", { required: true });
    const getRunningTaskDefinitionScript = path.join(
      __dirname,
      "../helpers/aws/get-running-task-definition.sh"
    );

    let stableTaskDefArn = "";
    await exec(
      `sh ${getRunningTaskDefinitionScript} --cluster "${cluster}" --service "${service}"`,
      undefined,
      {
        listeners: {
          stdout: (data: Buffer) => {
            stableTaskDefArn += data.toString();
          }
        }
      }
    );

    process.env.CURRENT_STABLE_TASKDEF_ARN = stableTaskDefArn;
    await exec(`sh ${path.join(__dirname, "build-task-definition.sh")}`);
  } catch (error) {
    core.setFailed(`Action failed with error ${error}`);
  }
}

run();
