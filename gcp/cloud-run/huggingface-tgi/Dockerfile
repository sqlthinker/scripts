# Deploy Text Generation Inference (TGI) container image by Hugging Face

# Hosted on Google Container Registry (GCR)
#FROM us-docker.pkg.dev/deeplearning-platform-release/gcr.io/huggingface-text-generation-inference-cu124.2-4.ubuntu2204.py311

# Hosted on GitHub Container Registry (ghcr.io) - official image by Hugging Face
FROM ghcr.io/huggingface/text-generation-inference:3.0.1

# Build argument for HF token
ARG HF_TOKEN
ARG MODEL_ID

ENV HF_TOKEN=${HF_TOKEN}
ENV MODEL_ID=${MODEL_ID}

# Download the model files, they are now part of the image build
RUN HF_TOKEN=${HF_TOKEN}  text-generation-server download-weights ${MODEL_ID}
