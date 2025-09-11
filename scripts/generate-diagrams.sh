#!/bin/bash
# Generate GCP Architecture Diagrams
# This script generates visual diagrams of the GCP infrastructure

set -e

echo "🎨 Generating GCP Architecture Diagrams..."

# Check if Python is available
if ! command -v python &> /dev/null; then
    echo "❌ Python is not installed or not in PATH"
    exit 1
fi

# Check if diagrams library is installed
if ! python -c "import diagrams" &> /dev/null; then
    echo "📦 Installing diagrams library..."
    python -m pip install diagrams
fi

# Generate diagrams
echo "🔄 Generating comprehensive architecture diagram..."
python generate_architecture_diagram.py

echo "✅ Diagrams generated successfully!"
echo "📁 Files created:"
echo "   - gcp_architecture_diagram.png"
echo "   - gcp_simplified_diagram.png"
echo ""
echo "💡 You can now view these diagrams in your documentation!"
