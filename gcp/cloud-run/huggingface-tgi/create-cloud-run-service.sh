#!/bin/bash
#
# 0BSD License
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE.
#
#---------------------------------------------------------------------------------
# Script Name:   create-cloud-run-service.sh
# Description:   Create a Cloud Run service from a Huggingface model
# Version:       1.0.0
# Author:        Anibal Santiago (@sqlthinker)
# Created:       2024-12-14
# Last Modified: 2024-12-15
# 
# How to run this script:
#   ./create-cloud-run-service.sh -p <PROJECT_ID> -l <LOCATION> -m <MODEL_ID> [-a "<CONTAINER_ARGS>"]
#     -p <PROJECT_ID>:       (Required) The Google Cloud Project ID.
#     -l <LOCATION>:         (Required) The Google Cloud region (e.g., us-central1).
#     -m <MODEL_ID>:         (Required) The Hugging Face model ID (e.g., meta-llama/Llama-3.2-3B-Instruct).
#     -a "<CONTAINER_ARGS>": (Optional) Additional arguments to pass to the container (e.g., "--max-concurrent-requests=8 --max-batch-prefill-tokens=4000").
#        Note: Suggested to set at least "--max-concurrent-requests=1" so the Cloud Run service will not stop after every request
#
#   Example:
#     ./create-cloud-run-service.sh -p my-project-id -l us-central1 -m meta-llama/Llama-3.2-3B-Instruct -a "--max-concurrent-requests=8"
# 
# Note:
# The script expects a model from Huggingface to be provided as MODEL="..."
#   Example: MODEL="meta-llama/Llama-3.1-8B-Instruct"
#
# The image name in Artifact Registry will automaticaly be the model name 
# but in lowercase and no punctuations. 
#   Example: IMAGE=meta-llama/llama-3-1-8b-instruct
#
# The service name in Cloud Run will automatically be the model name minus the 
# left part of the name which is the repository owner.
#   Example: SERVICE=llama-3-1-8b-instruct
#
# Requirements before running this script:
# 1) Set the Google Cloud project to use:
# gcloud config set project <YOUR-PROJECT-ID>
#
# 2) Enable the required APIs:
# gcloud services enable \
#   cloudbuild.googleapis.com \
#   run.googleapis.com \
#   secretmanager.googleapis.com
#
# 3) Create an Artifact Registry Repository called "cloud-run-huggingface":
# gcloud artifacts repositories create cloud-run-huggingface \
#   --repository-format=docker \
#   --location=us-central1 \
#   --project=<YOUR-PROJECT-ID>
#
# 4) Create a SECRET in Secret Manager for your Huggingface token. This is only 
#    needed for gated models, but the script will still try to access the secret, 
#    so still create one even if it is empty.
# gcloud secrets create HF_TOKEN --replication-policy="automatic"
# echo -n <huggingface-token-here> | gcloud secrets versions add HF_TOKEN --data-file=-
#---------------------------------------------------------------------------------

# Exit on error
set -e

# --- Configuration  ---
CONCURRENCY=8 # Default Cloud Run concurrency set to 8

# Parse command line arguments
while getopts "p:l:m:a:" opt; do
  case "$opt" in
    p) PROJECT_ID="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    a) ADDITIONAL_ARGS="$OPTARG";;
    \?)
      echo "Usage: $0 [-p project_id] [-l location] [-m model_name] [-a container_args]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_ID" || -z "$LOCATION" || -z "$MODEL" ]]; then
  echo "Error: Missing required arguments. Use -p, -l, and -m" >&2
  echo "Usage: $0 [-p project_id] [-l location] [-m model_name] [-a container_args]" >&2
  exit 1
fi

# Convert MODEL name tdyso lowercase
MODEL_LOWERCASE=$(echo "$MODEL" | tr '[:upper:]' '[:lower:]')

# The image name in Artifact Registry is all lowercase and "." converted to "-"
IMAGE=$(echo "$MODEL_LOWERCASE" | tr '.' '-')

# The Cloud Run service name is the model name minus the left part (repository owner)
SERVICE=$(echo "$IMAGE" | cut -d '/' -f 2)

echo ""
echo "Huggingface Model           : $MODEL"
echo "Artifact Registry Image Name: $IMAGE"
echo "Cloud Run Service Name      : $SERVICE"
echo ""

# Build the container image using Cloud Build
export HF_TOKEN=$(gcloud secrets versions access latest --secret="HF_TOKEN")
gcloud builds submit --config cloudbuild.yaml \
  --substitutions _HUGGINGFACE_TOKEN=$HF_TOKEN,_MODEL=$MODEL,_IMAGE=$IMAGE,_LOCATION=$LOCATION .

# Set the full image path
REGISTRY_HOST="$LOCATION-docker.pkg.dev"
FULL_IMAGE_PATH="$REGISTRY_HOST/$PROJECT_ID/cloud-run-huggingface/$IMAGE:latest"

# Deploy the service to Cloud Run
gcloud beta run deploy $SERVICE \
  --image "$FULL_IMAGE_PATH" \
  --args="$ADDITIONAL_ARGS" \
  --region $LOCATION \
  --port=8080 \
  --allow-unauthenticated \
  --memory=16Gi \
  --cpu=8 \
  --no-cpu-throttling \
  --gpu=1 \
  --gpu-type=nvidia-l4 \
  --max-instances=1 \
  --concurrency="$CONCURRENCY" \
  --timeout=3600 \
  --set-secrets=HF_TOKEN=HF_TOKEN:latest \
  --set-env-vars MODEL_ID="${MODEL}"

# Get the URL for the Cloud Run service
URL=$(gcloud run services describe $SERVICE --region $LOCATION | awk '/URL:/{print $2}')

# Make a request and capture the response
echo "Testing model by asking: What is the capital of France?"
RESPONSE=$(curl -s -X POST "$URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user","content": "What is the capital of France?"}]}')

# Check for "Paris" in the response
if [[ ! "$RESPONSE" == *Paris* ]]; then
  echo "Error: Response did not contain the word 'Paris'." >&2
  echo "Response received: $RESPONSE" >&2  # Print response for debugging
  exit 1
fi

# If we get here, it worked
echo "Success: The Cloud Run service is running at: $URL/v1/chat/completions"
exit 0
