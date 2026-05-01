#!/usr/bin/env bash
set -euo pipefail

# Set desired Python version (defaults to 3.12)
PY_VERSION="${1:-3.12}"
OS="$(uname -s)"

echo "Checking system requirements..."

# 1. Check for macOS or Linux
if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
    echo "❌ Error: This script supports macOS and Linux only." >&2
    exit 1
fi
echo "✅ OS detected: $OS"

# 2. Check and Install uv
if ! command -v uv &> /dev/null; then
    echo "⚠️  'uv' is not installed. Downloading and installing now..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Make the newly installed uv binary available to the remainder of THIS script session
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Verify the installation worked
    if ! command -v uv &> /dev/null; then
        echo "❌ Error: 'uv' installation failed or is not available in the PATH." >&2
        exit 1
    fi
    echo "✅ 'uv' installed successfully."
else
    echo "✅ 'uv' is already installed."
fi

# 3. Install Python and set as default
echo "📦 Installing Python ${PY_VERSION} via uv and setting as default..."
uv python install "${PY_VERSION}" --default

echo "✅ Python ${PY_VERSION} installation complete."

