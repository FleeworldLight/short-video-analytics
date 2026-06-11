#!/bin/bash
set -e

echo "=========================================="
echo "  短视频平台内容分析系统 - 全流程执行脚本"
echo "=========================================="

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

bash "$ROOT_DIR/docker/run.sh"
