#!/usr/bin/env bash
# ============================================================
# OpenClaw 系统环境诊断脚本
# 用途：检查设备是否满足 OpenClaw 部署要求
# 用法：chmod +x openclaw_check.sh && ./openclaw_check.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color
BOLD='\033[1m'

PASS=0
WARN=0
FAIL=0

pass()  { echo -e "  ${GREEN}✅ PASS${NC}  $1"; ((PASS++)); }
warn()  { echo -e "  ${YELLOW}⚠️  WARN${NC}  $1"; ((WARN++)); }
fail()  { echo -e "  ${RED}❌ FAIL${NC}  $1"; ((FAIL++)); }

echo ""
echo -e "${BOLD}🦞 OpenClaw 系统环境诊断${NC}"
echo "========================================"
echo ""

# --- 操作系统 ---
echo -e "${BLUE}[1/9] 操作系统${NC}"
OS_NAME=$(grep -oP '(?<=PRETTY_NAME=").*?(?=")' /etc/os-release 2>/dev/null || echo "未知")
echo "       $OS_NAME"
if grep -qiE "ubuntu|debian|linux" /etc/os-release 2>/dev/null; then
    pass "支持的 Linux 发行版"
else
    warn "未经测试的发行版，可能遇到兼容性问题"
fi
echo ""

# --- CPU 架构 ---
echo -e "${BLUE}[2/9] CPU 架构${NC}"
ARCH=$(uname -m)
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/.*:\s*//' | head -1)
CPU_CORES=$(nproc)
echo "       架构: $ARCH | 型号: $CPU_MODEL | 核心数: $CPU_CORES"
if [[ "$ARCH" == "aarch64" || "$ARCH" == "x86_64" ]]; then
    pass "$ARCH 架构受支持"
else
    fail "不支持的 CPU 架构: $ARCH"
fi
echo ""

# --- 内存 ---
echo -e "${BLUE}[3/9] 内存${NC}"
TOTAL_MEM_MB=$(free -m | awk '/Mem:/ {print $2}')
AVAIL_MEM_MB=$(free -m | awk '/Mem:/ {print $7}')
echo "       总计: ${TOTAL_MEM_MB} MB | 可用: ${AVAIL_MEM_MB} MB"
if (( AVAIL_MEM_MB >= 4096 )); then
    pass "可用内存充足 (≥ 4 GB)"
elif (( AVAIL_MEM_MB >= 2048 )); then
    warn "可用内存偏紧 (${AVAIL_MEM_MB} MB)，建议配置 Swap"
else
    fail "可用内存不足 (${AVAIL_MEM_MB} MB)，最少需要 2 GB"
fi
echo ""

# --- Swap ---
echo -e "${BLUE}[4/9] Swap 虚拟内存${NC}"
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
echo "       Swap: ${SWAP_TOTAL} MB"
if (( SWAP_TOTAL >= 2048 )); then
    pass "Swap 已配置 (${SWAP_TOTAL} MB)"
elif (( SWAP_TOTAL > 0 )); then
    warn "Swap 较小 (${SWAP_TOTAL} MB)，建议至少 4 GB"
else
    fail "未配置 Swap！建议创建 4 GB 交换文件"
    echo "       修复命令："
    echo "         sudo fallocate -l 4G /swapfile"
    echo "         sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
    echo "         echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
fi
echo ""

# --- 磁盘 ---
echo -e "${BLUE}[5/9] 磁盘空间${NC}"
AVAIL_DISK_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
DISK_USE_PCT=$(df / | awk 'NR==2 {print $5}')
echo "       可用: ${AVAIL_DISK_GB} GB | 使用率: ${DISK_USE_PCT}"
if (( AVAIL_DISK_GB >= 30 )); then
    pass "磁盘空间充足"
elif (( AVAIL_DISK_GB >= 20 )); then
    warn "磁盘空间够用但余量不大 (${AVAIL_DISK_GB} GB)"
else
    fail "磁盘空间不足 (${AVAIL_DISK_GB} GB)，至少需要 20 GB"
fi
echo ""

# --- Node.js ---
echo -e "${BLUE}[6/9] Node.js${NC}"
if command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VER" | grep -oP '\d+' | head -1)
    echo "       版本: $NODE_VER"
    if (( NODE_MAJOR >= 22 )); then
        pass "Node.js 版本满足要求 (≥ 22)"
    else
        fail "Node.js 版本过低，需要 v22+"
        echo "       修复：curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
        echo "             sudo apt-get install -y nodejs"
    fi
else
    fail "Node.js 未安装"
    echo "       修复：curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    echo "             sudo apt-get install -y nodejs"
fi
echo ""

# --- Python ---
echo -e "${BLUE}[7/9] Python${NC}"
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version)
    echo "       $PY_VER"
    pass "Python3 已安装"
else
    fail "Python3 未安装"
    echo "       修复：sudo apt-get install -y python3 python3-pip python3-venv"
fi
echo ""

# --- Git ---
echo -e "${BLUE}[8/9] Git${NC}"
if command -v git &>/dev/null; then
    GIT_VER=$(git --version)
    echo "       $GIT_VER"
    pass "Git 已安装"
else
    fail "Git 未安装"
    echo "       修复：sudo apt-get install -y git"
fi
echo ""

# --- 端口 18789 ---
echo -e "${BLUE}[9/9] 端口 18789${NC}"
if ss -tlnp 2>/dev/null | grep -q ":18789 "; then
    fail "端口 18789 已被占用"
    echo "       被占用进程："
    ss -tlnp | grep ":18789 "
else
    pass "端口 18789 空闲"
fi
echo ""

# --- OpenClaw 已安装？ ---
echo -e "${BLUE}[额外] OpenClaw 状态${NC}"
export PATH="$HOME/.npm-global/bin:$PATH"
if command -v openclaw &>/dev/null; then
    OC_VER=$(openclaw --version 2>/dev/null || echo "未知")
    echo "       版本: $OC_VER"
    pass "OpenClaw 已安装"
else
    echo "       OpenClaw 尚未安装"
fi
echo ""

# --- 汇总 ---
echo "========================================"
echo -e "${BOLD}诊断结果汇总${NC}"
echo -e "  ${GREEN}通过: $PASS${NC}  ${YELLOW}警告: $WARN${NC}  ${RED}失败: $FAIL${NC}"
echo ""

if (( FAIL == 0 && WARN == 0 )); then
    echo -e "${GREEN}${BOLD}🎉 全部通过！你的设备已准备好安装 OpenClaw。${NC}"
elif (( FAIL == 0 )); then
    echo -e "${YELLOW}${BOLD}⚠️  有 $WARN 个警告项，建议处理后再安装。${NC}"
else
    echo -e "${RED}${BOLD}❌ 有 $FAIL 个必须修复的问题，请按提示修复后重新运行此脚本。${NC}"
fi
echo ""
