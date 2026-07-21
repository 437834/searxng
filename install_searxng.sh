#!/bin/bash
# ============================================================
# SearXNG Termux 一键安装脚本
# 用法：bash <(curl -s https://raw.githubusercontent.com/437834/searxng/main/install_searxng.sh)
# 每个步骤会检查是否已完成，已完成则跳过，可安全重复运行
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
skip()  { echo -e "${YELLOW}[跳过]${NC} $1"; }

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
info "检查 Termux 包管理器..."
if [ -f /tmp/.searxng_termux_updated ]; then
    skip "Termux 已更新，跳过"
else
    info "更新 Termux 包管理器..."
    TERM=noninteractive pkg update -y
    TERM=noninteractive pkg upgrade -y
    touch /tmp/.searxng_termux_updated
    ok "Termux 更新完成"
fi

# ---------- 安装 proot-distro ----------
info "检查 proot-distro..."
if command -v proot-distro &>/dev/null; then
    skip "proot-distro 已安装，跳过"
else
    info "安装 proot-distro..."
    pkg install proot-distro -y
    ok "proot-distro 安装完成"
fi

# ---------- 安装 Ubuntu ----------
info "检查 Ubuntu..."
if proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
    skip "Ubuntu 已安装，跳过"
else
    info "安装 Ubuntu（可能需要几分钟）..."
    proot-distro install ubuntu
    ok "Ubuntu 安装完成"
fi

# ---------- Ubuntu 内部安装 ----------
info "进入 Ubuntu 检查 SearXNG 安装状态..."

proot-distro login ubuntu -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive

# 检查标志文件
SEARXNG_DONE="/tmp/.searxng_install_done"

if [ -f "$SEARXNG_DONE" ]; then
    echo "[跳过] SearXNG 已安装完成，跳过所有 Ubuntu 内部步骤"
    exit 0
fi

# --- 更新 Ubuntu ---
echo "[信息] 检查 Ubuntu 包管理器..."
if [ -f /tmp/.searxng_apt_updated ]; then
    echo "[跳过] Ubuntu 已更新，跳过"
else
    echo "[信息] 更新 Ubuntu..."
    apt update -y
    touch /tmp/.searxng_apt_updated
    echo "[成功] Ubuntu 更新完成"
fi

# --- 安装编译依赖 ---
echo "[信息] 检查编译依赖..."
NEEDED="python3 python3-pip python3-venv python3-dev git build-essential libxml2-dev libxslt1-dev libffi-dev libssl-dev zlib1g-dev libjpeg-dev libyaml-dev"
MISSING=""
for pkg in $NEEDED; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -z "$MISSING" ]; then
    echo "[跳过] 编译依赖已全部安装，跳过"
else
    echo "[信息] 安装缺失依赖:$MISSING"
    apt install -y -o Dpkg::Options::="--force-confold" $MISSING
    echo "[成功] 依赖安装完成"
fi

# --- 创建 Python 虚拟环境 ---
echo "[信息] 检查 Python 虚拟环境..."
if [ -d ~/searxng-env ] && [ -f ~/searxng-env/bin/activate ]; then
    echo "[跳过] 虚拟环境已存在，跳过"
else
    echo "[信息] 创建 Python 虚拟环境..."
    cd ~
    python3 -m venv ~/searxng-env
    echo "[成功] 虚拟环境创建完成"
fi
source ~/searxng-env/bin/activate

# --- 升级 pip ---
echo "[信息] 检查 pip 版本..."
CURRENT_PIP=$(pip --version 2>/dev/null | awk "{print \$2}")
pip install --upgrade pip setuptools wheel
echo "[成功] pip 已是最新"

# --- 克隆 SearXNG ---
echo "[信息] 检查 SearXNG 源码..."
if [ -d ~/searxng ] && [ -f ~/searxng/setup.py ]; then
    echo "[跳过] SearXNG 目录已存在，跳过克隆"
    cd ~/searxng
    git pull || true
else
    echo "[信息] 克隆 SearXNG..."
    rm -rf ~/searxng
    git clone https://github.com/searxng/searxng.git ~/searxng
    echo "[成功] 克隆完成"
fi

# --- 安装 Python 依赖 ---
echo "[信息] 检查 Python 依赖..."
if python3 -c "import lxml, yaml, flask" 2>/dev/null; then
    echo "[跳过] Python 依赖已安装，跳过"
else
    echo "[信息] 安装 Python 依赖..."
    pip install -r ~/searxng/requirements.txt
    pip install -r ~/searxng/requirements-server.txt
    echo "[成功] Python 依赖安装完成"
fi

# --- 安装 SearXNG 本体 ---
echo "[信息] 检查 SearXNG 本体..."
if python3 -c "import searx" 2>/dev/null; then
    echo "[跳过] SearXNG 本体已安装，跳过"
else
    echo "[信息] 安装 SearXNG 本体..."
    pip install --no-build-isolation ~/searxng
    echo "[成功] SearXNG 安装完成"
fi

# --- 修复已知 Bug ---
echo "[信息] 检查 Bug 修复..."
if grep -q "default_doi_resolver" ~/searxng/searx/settings_defaults.py 2>/dev/null; then
    echo "[跳过] Bug 已修复，跳过"
else
    echo "[信息] 修复已知 Bug..."
    python3 << PYFIX
with open("/root/searxng/searx/settings_defaults.py", "r") as f:
    c = f.read()
if "default_doi_resolver" not in c:
    c = c.replace(
        "'doi_resolvers': {},",
        "'doi_resolvers': {\"oadoi.org\": \"https://doi.org/\"},\n    \"default_doi_resolver\": \"oadoi.org\","
    )
with open("/root/searxng/searx/settings_defaults.py", "w") as f:
    f.write(c)
PYFIX
    echo "[成功] Bug 修复完成"
fi

# --- 写入配置文件 ---
echo "[信息] 检查配置文件..."
if [ -f ~/searxng/searx/settings.yml ]; then
    echo "[跳过] 配置文件已存在，跳过"
else
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
  secret_key: "\${SK}"
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
YAML
    echo "[成功] 配置写入完成"
fi

# --- 验证安装 ---
echo "[信息] 验证安装..."
python3 -c "import searx; print('[成功] SearXNG 导入验证通过')"

# 标记全部完成
touch "$SEARXNG_DONE"
echo "[成功] Ubuntu 内部安装全部完成"
'

# ---------- 部署引擎管理器 ----------
info "检查引擎管理器..."
UBUNTU_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/root"
if [ -f "$UBUNTU_ROOT/searxng/engine_mgr.py" ]; then
    skip "引擎管理器已部署，跳过"
else
    info "部署引擎管理器..."

    cat > /tmp/engine_mgr.py << 'PYEOF'
#!/usr/bin/env python3
"""SearXNG Engine Manager"""
import yaml
import os
import shutil
from datetime import datetime

SETTINGS = os.path.expanduser("~/searxng/searx/settings.yml")

ENGINE_LIST = [
    ("baidu", "baidu", "百度", "中国搜索引擎，无需翻墙"),
    ("bing", "bing", "Bing", "微软搜索引擎"),
    ("duckduckgo", "duckduckgo", "DuckDuckGo", "隐私搜索引擎"),
    ("google", "google", "Google", "全球流行搜索引擎"),
    ("google images", "google_images", "Google 图片", "图片搜索"),
    ("google news", "google_news", "Google 新闻", "新闻搜索"),
    ("google videos", "google_videos", "Google 视频", "视频搜索"),
    ("google scholar", "google_scholar", "Google 学术", "学术论文搜索"),
    ("wikipedia", "wikipedia", "Wikipedia", "自由百科全书"),
    ("wikidata", "wikidata", "Wikidata", "结构化知识库"),
    ("brave", "brave", "Brave Search", "隐私搜索引擎"),
    ("startpage", "startpage", "Startpage", "匿名搜索引擎"),
    ("moegirl", "moegirl", "萌娘百科", "ACG 百科全书"),
    ("yahoo", "yahoo", "Yahoo", "雅虎搜索"),
    ("yandex", "yandex", "Yandex", "俄罗斯搜索引擎"),
    ("qwant", "qwant", "Qwant", "法国隐私搜索引擎"),
    ("ecosia", "ecosia", "Ecosia", "环保搜索引擎"),
    ("github", "github", "GitHub", "代码托管平台搜索"),
    ("currency convert", "currency_convert", "货币转换", "实时汇率转换"),
    ("searx instances", "searx_instances", "SearX 实例", "搜索其他 SearX 实例"),
]

ENGINE_MAP = {e[0]: e[1] for e in ENGINE_LIST}


def load_settings():
    try:
        with open(SETTINGS, "r") as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return {}


def backup_settings():
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    shutil.copy2(SETTINGS, f"{SETTINGS}.bak.{ts}")


def save_settings(settings):
    backup_settings()
    with open(SETTINGS, "w") as f:
        yaml.dump(settings, f, default_flow_style=False, allow_unicode=True, sort_keys=False)


def get_disabled_set(settings):
    disabled = set()
    for eng in settings.get("engines", []):
        if isinstance(eng, dict) and eng.get("disabled", False):
            disabled.add(eng.get("name", ""))
    return disabled


def set_engine_disabled(settings, engine_name, disabled):
    engines = settings.get("engines", [])
    if disabled:
        found = False
        for eng in engines:
            if isinstance(eng, dict) and eng.get("name") == engine_name:
                eng["disabled"] = True
                found = True
                break
        if not found:
            module = ENGINE_MAP.get(engine_name, "")
            engines.append({"name": engine_name, "engine": module, "disabled": True})
    else:
        engines = [
            e for e in engines
            if not (isinstance(e, dict) and e.get("name") == engine_name)
        ]
    settings["engines"] = engines


def show_menu(disabled_set):
    print()
    print("=" * 60)
    print("  SearXNG 引擎管理")
    print("=" * 60)
    print()
    print(f"  {'#':>3}  {'状态':<10}  {'名称':<16}  {'说明'}")
    print(f"  {'---':>3}  {'------':<10}  {'----':<16}  {'----'}")
    for i, (name, _module, display, desc) in enumerate(ENGINE_LIST, 1):
        if name in disabled_set:
            status = "❌ 已禁用"
        else:
            status = "✅ 已启用"
        print(f"  {i:3d}  {status:<10}  {display:<16}  {desc}")
    print()
    print("  操作：")
    print("    输入数字    切换启用/禁用")
    print("    all         启用列表中全部引擎")
    print("    none        禁用列表中全部引擎")
    print("    reset       恢复默认配置")
    print("    0           返回上级菜单")
    print()


def main():
    try:
        while True:
            settings = load_settings()
            disabled_set = get_disabled_set(settings)
            show_menu(disabled_set)

            choice = input("  请选择: ").strip().lower()

            if choice == "0":
                print("  已返回主菜单")
                break
            elif choice == "all":
                settings = load_settings()
                engines = [
                    e for e in settings.get("engines", [])
                    if not (isinstance(e, dict) and e.get("name") in ENGINE_MAP)
                ]
                settings["engines"] = engines
                save_settings(settings)
                print("  已启用全部引擎")
            elif choice == "none":
                settings = load_settings()
                engines = [
                    e for e in settings.get("engines", [])
                    if not (isinstance(e, dict) and e.get("name") in ENGINE_MAP)
                ]
                for name, module, _, _ in ENGINE_LIST:
                    engines.append({"name": name, "engine": module, "disabled": True})
                settings["engines"] = engines
                save_settings(settings)
                print("  已禁用全部引擎")
            elif choice == "reset":
                settings = load_settings()
                engines = [
                    e for e in settings.get("engines", [])
                    if not (isinstance(e, dict) and e.get("name") in ENGINE_MAP)
                ]
                settings["engines"] = engines
                save_settings(settings)
                print("  已恢复默认配置")
            elif choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(ENGINE_LIST):
                    name, module, display, _ = ENGINE_LIST[idx]
                    settings = load_settings()
                    disabled_set = get_disabled_set(settings)
                    if name in disabled_set:
                        set_engine_disabled(settings, name, False)
                        save_settings(settings)
                        print(f"  已启用: {display}")
                    else:
                        set_engine_disabled(settings, name, True)
                        save_settings(settings)
                        print(f"  已禁用: {display}")
                else:
                    print("  无效选择，请重新输入")
            else:
                print("  无效选择，请重新输入")
    except KeyboardInterrupt:
        print("\n  已返回主菜单")


if __name__ == "__main__":
    main()
PYEOF

    cp /tmp/engine_mgr.py "$UBUNTU_ROOT/searxng/engine_mgr.py"
    rm -f /tmp/engine_mgr.py
    ok "引擎管理器部署完成"
fi

# ---------- 创建主菜单脚本 ----------
info "检查主菜单脚本..."
if [ -f ~/sear ]; then
    skip "主菜单脚本已存在，跳过"
else
    info "创建主菜单脚本..."

    cat > ~/sear << 'MENU_EOF'
#!/bin/bash
LOG_DIR=~/searxng-logs
mkdir -p "$LOG_DIR"

start_searxng() {
    local logfile="$LOG_DIR/searxng_$(date +%Y%m%d_%H%M%S).log"
    echo ""
    echo "  日志文件: $logfile"
    proot-distro login ubuntu -- bash -c "
        source ~/searxng-env/bin/activate
        export SEARXNG_SETTINGS_PATH=~/searxng/searx/settings.yml
        cd ~/searxng
        echo ''
        echo '================================'
        echo '  SearXNG 已启动'
        echo '  访问地址: http://localhost:8888'
        echo '  按 Ctrl+C 停止服务'
        echo '================================'
        echo ''
        python3 -m searx.webapp 2>&1
    " | tee "$logfile"
}

view_logs() {
    echo ""
    echo "================================"
    echo "  日志查看"
    echo "================================"
    echo ""

    logfiles=($(ls -t "$LOG_DIR"/searxng_*.log 2>/dev/null))

    if [ ${#logfiles[@]} -eq 0 ]; then
        echo "  暂无日志文件"
        echo "  （需要先启动一次 SearXNG 才会产生日志）"
        return
    fi

    echo "  可用日志文件："
    echo ""
    for i in "${!logfiles[@]}"; do
        local fname=$(basename "${logfiles[$i]}")
        local fsize=$(du -h "${logfiles[$i]}" | cut -f1)
        local lines=$(wc -l < "${logfiles[$i]}")
        echo "  $((i+1)). $fname  ($fsize, ${lines}行)"
    done
    echo ""
    echo "  操作："
    echo "    输入数字      查看该日志"
    echo "    s + 关键词    搜索日志（如 s baidu）"
    echo "    e             查看所有错误日志"
    echo "    t             查看最近30条日志"
    echo "    c             清空所有日志"
    echo "    0             返回"
    echo ""
    read -p "  请选择: " log_choice

    case $log_choice in
        0)
            return
            ;;
        e)
            echo ""
            echo "  ========== 所有错误日志 =========="
            echo ""
            grep -i -n "error\|traceback\|exception\|fail" "$LOG_DIR"/searxng_*.log 2>/dev/null || echo "  没有找到错误日志"
            echo ""
            ;;
        t)
            echo ""
            echo "  ========== 最近30条日志 =========="
            echo ""
            tail -30 "$LOG_DIR"/searxng_*.log 2>/dev/null | tail -30
            echo ""
            ;;
        c)
            read -p "  确定要清空所有日志吗？(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -f "$LOG_DIR"/searxng_*.log
                echo "  日志已清空"
            fi
            ;;
        s*)
            local keyword="${log_choice#s }"
            keyword=$(echo "$keyword" | xargs)
            if [ -z "$keyword" ]; then
                read -p "  请输入搜索关键词: " keyword
            fi
            echo ""
            echo "  ========== 搜索: $keyword =========="
            echo ""
            grep -i -n "$keyword" "$LOG_DIR"/searxng_*.log 2>/dev/null || echo "  没有找到匹配内容"
            echo ""
            ;;
        [0-9]*)
            local idx=$((log_choice - 1))
            if [ $idx -ge 0 ] && [ $idx -lt ${#logfiles[@]} ]; then
                echo ""
                echo "  ========== ${logfiles[$idx]} =========="
                echo ""
                less "${logfiles[$idx]}"
            else
                echo "  无效选择"
            fi
            ;;
        *)
            echo "  无效选择"
            ;;
    esac
}

while true; do
    echo ""
    echo "================================"
    echo "  SearXNG 搜索引擎管理"
    echo "================================"
    echo ""
    echo "  1. 启动 SearXNG"
    echo "  2. 引擎管理"
    echo "  3. 查看当前配置"
    echo "  4. 编辑配置文件"
    echo "  5. 查看日志"
    echo "  6. 卸载 SearXNG"
    echo "  0. 退出"
    echo ""
    read -p "  请选择 [0-6]: " choice
    case $choice in
        1)
            start_searxng
            ;;
        2)
            proot-distro login ubuntu -- bash -c '
                source ~/searxng-env/bin/activate
                python3 ~/searxng/engine_mgr.py
            '
            ;;
        3)
            proot-distro login ubuntu -- bash -c '
                echo ""
                echo "========== settings.yml =========="
                echo ""
                cat ~/searxng/searx/settings.yml
                echo ""
                echo "=================================="
            '
            ;;
        4)
            proot-distro login ubuntu -- bash -c '
                echo ""
                echo "  用法：i 编辑  Esc+:wq 保存  Esc+:q! 退出"
                echo ""
                vi ~/searxng/searx/settings.yml
            '
            ;;
        5)
            view_logs
            ;;
        6)
            echo ""
            read -p "  确定要卸载 SearXNG 吗？(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                echo "  正在卸载..."
                proot-distro remove ubuntu 2>/dev/null
                rm -f ~/sear
                rm -rf "$LOG_DIR"
                echo "  卸载完成！"
                exit 0
            else
                echo "  取消卸载"
            fi
            ;;
        0)
            echo "  再见！"
            exit 0
            ;;
        *)
            echo "  无效选择，请重新输入"
            ;;
    esac
done
MENU_EOF

    chmod +x ~/sear
    ok "主菜单脚本创建完成"
fi

# ---------- 完成 ----------
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  安装全部完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "  启动方式：${CYAN}~/sear${NC}"
echo -e "  浏览器访问：${CYAN}http://localhost:8888${NC}"
echo ""
