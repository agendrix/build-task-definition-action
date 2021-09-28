import * as core from "@actions/core";

/**
 * Validate that all required inputs were provided
 * If not, it will throw.
 */
export function validateRequiredInputs(requiredInputs: Array<string>): void {
  for (const requiredInput of requiredInputs) {
    core.getInput(requiredInput, { required: true });
  }
}
