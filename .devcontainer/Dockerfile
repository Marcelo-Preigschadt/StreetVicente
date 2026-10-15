FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 curl ripgrep ca-certificates libfontconfig1 libx11-6 libxcursor1 \
    libxinerama1 libxrandr2 libxi6 libgl1 libasound2t64 \
    && rm -rf /var/lib/apt/lists/*
