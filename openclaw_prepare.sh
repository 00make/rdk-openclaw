#!/usr/bin/env bash
# ============================================================
# OpenClaw 一键前置依赖安装脚本
# 用途：自动完成 Swap 配置 + Node.js 22 安装 + 系统依赖安装
# 用法：chmod +x openclaw_prepare.sh && sudo ./openclaw_prepare.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：请使用 sudo 运行此脚本${NC}"
    echo "用法：sudo ./openclaw_prepare.sh"
    exit 1
fi

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(eval echo "~$REAL_USER")

echo ""
echo -e "${BOLD}🦞 OpenClaw 前置依赖安装脚本${NC}"
echo "========================================"
echo ""

# ==========================================
# Step 1: Swap
# ==========================================
echo -e "${BLUE}[1/3] 配置 Swap 虚拟内存${NC}"

SWAP_SIZE="4G"
SWAP_FILE="/swapfile"

if swapon --show | grep -q "$SWAP_FILE"; then
    echo -e "  ${GREEN}✓${NC} Swap 已存在且已激活，跳过"
elif [[ -f "$SWAP_FILE" ]]; then
    echo "  Swap 文件已存在但未激活，正在激活..."
    swapon "$SWAP_FILE"
    echo -e "  ${GREEN}✓${NC} Swap 已激活"
else
    echo "  正在创建 $SWAP_SIZE Swap 文件..."
    fallocate -l "$SWAP_SIZE" "$SWAP_FILE"
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
    swapon "$SWAP_FILE"
    
    # 检查 fstab 是否已有条目
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        echo "  已添加到 /etc/fstab（开机自动挂载）"
    fi
    
    echo -e "  ${GREEN}✓${NC} $SWAP_SIZE Swap 创建并激活成功"
fi

swapon --show
echo ""

# ==========================================
# Step 2: Node.js 22
# ==========================================
echo -e "${BLUE}[2/3] 安装 Node.js 22${NC}"

REQUIRED_NODE_MAJOR=22

if command -v node &>/dev/null; then
    CURRENT_MAJOR=$(node --version | grep -oP '\d+' | head -1)
    if (( CURRENT_MAJOR >= REQUIRED_NODE_MAJOR )); then
        echo -e "  ${GREEN}✓${NC} Node.js $(node --version) 已满足要求，跳过"
    else
        echo "  当前版本 $(node --version) 过低，正在升级..."
        curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE_MAJOR}.x | bash -
        apt-get install -y nodejs
        echo -e "  ${GREEN}✓${NC} Node.js 已升级至 $(node --version)"
    fi
else
    echo "  Node.js 未安装，正在安装 v${REQUIRED_NODE_MAJOR}..."
    curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE_MAJOR}.x | bash -
    apt-get install -y nodejs
    echo -e "  ${GREEN}✓${NC} Node.js $(node --version) 安装完成"
fi

echo "  Node: $(node --version) | npm: $(npm --version)"
echo ""

# ==========================================
# Step 3: 系统依赖
# ==========================================
echo -e "${BLUE}[3/3] 安装系统依赖${NC}"

DEPS=(python3-venv python3-pip git curl wget)
NEED_INSTALL=()

for dep in "${DEPS[@]}"; do
    if dpkg -l "$dep" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $dep 已安装"
    else
        NEED_INSTALL+=("$dep")
    fi
done

if (( ${#NEED_INSTALL[@]} > 0 )); then
    echo "  正在安装: ${NEED_INSTALL[*]}"
    apt-get install -y "${NEED_INSTALL[@]}"
    echo -e "  ${GREEN}✓${NC} 依赖安装完成"
else
    echo -e "  ${GREEN}✓${NC} 所有依赖已就绪"
fi

echo ""

# ==========================================
# 汇总
# ==========================================
echo "========================================"
echo -e "${GREEN}${BOLD}✅ 前置依赖全部就绪！${NC}"
echo ""
echo "接下来请以普通用户身份（不要用 sudo）运行以下命令安装 OpenClaw："
echo ""
echo -e "  ${BOLD}curl -fsSL https://openclaw.ai/install.sh | bash${NC}"
echo ""
echo "安装完成后执行初始化："
echo ""
echo -e "  ${BOLD}openclaw onboard --install-daemon${NC}"
echo ""
echo "如果提示 command not found，请先执行："
echo ""
echo -e "  ${BOLD}export PATH=\"\$HOME/.npm-global/bin:\$PATH\"${NC}"
echo ""
