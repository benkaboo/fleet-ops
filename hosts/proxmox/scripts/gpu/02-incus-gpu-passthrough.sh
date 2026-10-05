#!/usr/bin/env bash
# ==============================================================================
# Future Migration Reference: Incus GPU Passthrough Blueprint
# Target Platform: Incus Container Host (Linux)
# Container Name: services (or equivalent Docker host)
# ==============================================================================
set -euo pipefail

CONTAINER_NAME="${1:-services}"

echo "======================================================================"
echo "    Incus GPU Passthrough Configuration Reference"
echo "    Container: $CONTAINER_NAME"
echo "======================================================================"
echo ""
echo "Incus natively manages GPU cgroups, udev permissions, and device nodes"
echo "without requiring manual major number calculation or config file edits."
echo ""
echo "--- COMMAND 1: Add NVIDIA GPU to Container ---"
echo "incus config device add $CONTAINER_NAME gpu gpu"
echo ""
echo "--- OPTIONAL: Specify Specific PCI Device if Multiple GPUs ---"
echo "incus config device add $CONTAINER_NAME gpu gpu pci=0000:01:00.0"
echo ""
echo "--- COMMAND 2: Verify GPU Presence in Container ---"
echo "incus exec $CONTAINER_NAME -- ls -la /dev/nvidia*"
echo ""
echo "======================================================================"
