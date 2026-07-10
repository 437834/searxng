#!/bin/bash
# ============================================================
# SearXNG Termux 一键安装脚本
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[信息]${NC} $1"; }
ok()    { echo -e "${GREEN}[成功]${NC} $1"; }
warn()  { echo -e "${YELLOW}[注意]${NC} $1"; }
fail()  { echo -e "${RED}[失败]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}  SearXNG Termux 一键安装脚本  ${NC}"
echo -e "${CYAN}================================${NC}"
echo ""

# ---------- 检查环境 ----------
info "检查运行环境..."
if [ ! -d "/data/data/com.termux" ]; then
    fail "请在 Termux 中运行此脚本！"
fi

# ---------- 更新 Termux ----------
info "更新 Termux 包管理器..."
pkg update -y && pkg upgrade -y
ok "Termux 更新完成"

# ---------- 安装 proot-distro ----------
info "安装 proot-distro..."
pkg install proot-distro -y
ok "proot-distro 安装完成"

# ---------- 安装 Ubuntu ----------
if proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
    warn "Ubuntu 已安装，跳过"
else
    info "安装 Ubuntu（可能需要几分钟）..."
    proot-distro install ubuntu
    ok "Ubuntu 安装完成"
fi

# ---------- Ubuntu 内部安装 ----------
info "进入 Ubuntu 安装 SearXNG..."

proot-distro login ubuntu -- bash -c '
set -e

echo "[信息] 更新 Ubuntu..."
apt update > /dev/null 2>&1

echo "[信息] 安装编译依赖..."
apt install -y python3 python3-pip python3-venv python3-dev git build-essential libxml2-dev libxslt1-dev libffi-dev libssl-dev zlib1g-dev libjpeg-dev libyaml-dev > /dev/null 2>&1
echo "[成功] 依赖安装完成"

echo "[信息] 创建 Python 虚拟环境..."
cd ~
python3 -m venv ~/searxng-env
source ~/searxng-env/bin/activate

echo "[信息] 升级 pip..."
pip install --upgrade pip setuptools wheel > /dev/null 2>&1

if [ -d ~/searxng ]; then
    echo "[注意] SearXNG 目录已存在，拉取最新代码..."
    cd ~/searxng
    git pull
else
    echo "[信息] 克隆 SearXNG..."
    git clone https://github.com/searxng/searxng.git ~/searxng
fi

echo "[信息] 安装 Python 依赖..."
pip install -r ~/searxng/requirements.txt > /dev/null 2>&1
pip install -r ~/searxng/requirements-server.txt > /dev/null 2>&1

echo "[信息] 安装 SearXNG 本体..."
pip install --no-build-isolation ~/searxng > /dev/null 2>&1
echo "[成功] SearXNG 安装完成"

echo "[信息] 修复已知 Bug..."
python3 << PYFIX
with open("/root/searxng/searx/settings_defaults.py", "r") as f:
    c = f.read()

if "default_doi_resolver" not in c:
    c = c.replace(
        "'doi_resolvers': {},",
        "'doi_resolvers': {'oadoi.org': 'https://doi.org/'},\n    'default_doi_resolver': 'oadoi.org',"
    )

with open("/root/searxng/searx/settings_defaults.py", "w") as f:
    f.write(c)
PYFIX
echo "[成功] Bug 修复完成"

echo "[信息] 写入配置文件..."
mkdir -p ~/searxng/searx
SK=$(python3 -c "import secrets; print(secrets.token_hex(32))")

cat > ~/searxng/searx/settings.yml << YAML
use_default_settings: true
general:
  instance_name: "SearXNG"
  debug: false

search:
  safe_search: 0
  autocomplete: ""
  default_lang: "zh-CN"
  formats:
    - html
    - json

server:
  secret_key: "${SK}"
  bind_address: "0.0.0.0"
  port: 8888
  limiter: false
  image_proxy: false
  public_instance: false
  default_http_headers:
    X-Content-Type-Options: nosniff
    X-Download-Options: noopen
    X-Robots-Tag: noindex, nofollow
    Referrer-Policy: no-referrer
    Access-Control-Allow-Origin: "*"
    Access-Control-Allow-Methods: "GET, POST"
    Access-Control-Allow-Headers: "*"

ui:
  static_use_hash: true

outgoing:
  request_timeout: 10.0

engines:
  - name: baidu
    engine: baidu
    shortcut: bd
    disabled: false
    weight: 2
  - name: bing
    engine: bing
    shortcut: bi
    disabled: false
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    disabled: false
  - name: wikipedia
    engine: wikipedia
    shortcut: wp
    disabled: false
    display_type: ["infobox", "list"]
YAML

echo "[成功] 配置写入完成"

echo "[信息] 验证安装..."
python3 -c "import searx; print('[成功] SearXNG 导入验证通过')"

echo ""
echo "================================"
echo "  Ubuntu 内部安装全部完成！"
echo "================================"
'

# ---------- 创建启动脚本 ----------
info "创建一键启动脚本..."

cat > ~/sear << 'LAUNCH'
#!/bin/bash
proot-distro login ubuntu -- bash -c '
  source ~/searxng-env/bin/activate
  export SEARXNG_SETTINGS_PATH=~/searxng/searx/settings.yml
  cd ~/searxng
  echo ""
  echo "================================"
  echo "  SearXNG 搜索引擎"
  echo "  访问地址: http://localhost:8888"
  echo "  按 Ctrl+C 停止服务"
  echo "================================"
  echo ""
  python3 -m searx.webapp
'
LAUNCH
chmod +x ~/sear

# ---------- 完成 ----------
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  安装全部完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "  启动方式：${CYAN}~/sear${NC}"
echo -e "  浏览器访问：${CYAN}http://localhost:8888${NC}"
echo ""
