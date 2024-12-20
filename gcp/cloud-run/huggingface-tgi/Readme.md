# Cloud Run Deployment for Hugging Face Text Generation Inference (TGI)

This repository contains the files necessary to deploy a Hugging Face text generation model to Google Cloud Run using Text Generation Inference (TGI).

## Overview

This solution leverages Docker, Google Cloud Build, and Google Cloud Run to create a scalable and accessible service for your Hugging Face models.

*   **`create-cloud-run-service.sh`**: A Bash script that orchestrates the entire deployment process, from building the Docker image to deploying it to Cloud Run.
*   **`Dockerfile`**: Contains the instructions for building the Docker container image, using the official Hugging Face TGI image and including the model weights.
*   **`cloudbuild.yaml`**: A configuration file for Google Cloud Build, defining the build steps, image storage location, and build-time variables.

## Prerequisites

Before using these files, ensure you have the following:

1.  A Google Cloud Platform (GCP) project.
2.  The Google Cloud SDK (`gcloud`) installed and configured.
3.  The following Google Cloud APIs enabled in your project:
    *   `cloudbuild.googleapis.com`
    *   `run.googleapis.com`
    *   `secretmanager.googleapis.com`
4.  A Google Artifact Registry repository named `cloud-run-huggingface` in your desired region (e.g., `us-central1`). This repository should be configured to store Docker images.
5.  A secret named `HF_TOKEN` in Google Secret Manager storing your Hugging Face API token (even for non-gated models, keep it empty if needed).

## Usage

1.  **Clone the repository:**

    ```bash
    git clone <repository_url>
    cd <repository_name>
    ```

2.  **Run the `create-cloud-run-service.sh` script:**

    ```bash
    ./create-cloud-run-service.sh -p <PROJECT_ID> -l <LOCATION> -m <MODEL_ID> [-a "<CONTAINER_ARGS>"]
    ```

    *   `-p <PROJECT_ID>`: (Required) Your Google Cloud Project ID.
    *   `-l <LOCATION>`: (Required) Your Google Cloud region (e.g., `us-central1`).
    *   `-m <MODEL_ID>`: (Required) The Hugging Face model ID (e.g., `meta-llama/Llama-3.2-3B-Instruct`).
    *   `-a "<CONTAINER_ARGS>"`: (Optional) Additional arguments to pass to the container (e.g., `--max-concurrent-requests=8 --max-batch-prefill-tokens=4000`). Suggest to set at least `--max-concurrent-requests=1` to prevent the service from stopping after every request.

    **Example:**

    ```bash
    ./create-cloud-run-service.sh -p my-project-id -l us-central1 -m meta-llama/Llama-3.2-3B-Instruct -a "--max-concurrent-requests=8"
    ```

## Script Details

### `create-cloud-run-service.sh`

*   Retrieves your Hugging Face token from Google Secret Manager.
*   Builds a Docker image using `cloudbuild.yaml` by passing the model ID and the token.
*   Deploys the built image to Cloud Run.
*   Configures Cloud Run to use 1 GPU, 8 CPUs, and 16Gi of RAM.
*   Tests if the deployment works as expected by asking a simple question and verifying the answer.

### `Dockerfile`

*   Uses the official Hugging Face TGI image as a base.
*   Defines build-time arguments for the Hugging Face token and model ID.
*   Downloads the weights for the specified model using the `text-generation-server download-weights` command.

### `cloudbuild.yaml`

*   Configures Google Cloud Build to build a Docker image.
*   Uses the `Dockerfile` in the current directory.
*   Passes build-time arguments, the Hugging Face token, and the model ID.
*   Tags and pushes the resulting Docker image to Google Artifact Registry.

## Notes

* The script expects a model from Huggingface to be provided as `MODEL="..."`. For example: `MODEL="meta-llama/Llama-3.2-3B-Instruct"`
* The image name in Artifact Registry will automatically be the model name but in lowercase and with the characters "." replaced with "-". For example: `IMAGE=meta-llama/llama-3.2-3b-instruct`.
* The service name in Cloud Run will automatically be the model name minus the left part of the name which is the repository owner. For example: `SERVICE=llama-3.2-3b-instruct`.

## License

This project is licensed under the 0BSD License - see the `LICENSE` file for details.