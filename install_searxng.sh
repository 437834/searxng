#!/bin/bash
# ============================================================
# SearXNG Termux ä¸é®å®è£èæ¬
# ç¨æ³ï¼bash <(curl -s https://raw.githubusercontent.com/437834/searxng/main/install_searxng.sh)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[ä¿¡æ¯]${NC} $1"; }
ok()    { echo -e "${GREEN}[æå]${NC} $1"; }
warn()  { echo -e "${YELLOW}[æ³¨æ]${NC} $1"; }
fail()  { echo -e "${RED}[å¤±è´¥]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}  SearXNG Termux ä¸é®å®è£èæ¬  ${NC}"
echo -e "${CYAN}================================${NC}"
echo ""

# ---------- æ£æ¥ç¯å¢ ----------
info "æ£æ¥è¿è¡ç¯å¢..."
if [ ! -d "/data/data/com.termux" ]; then
    fail "è¯·å¨ Termux ä¸­è¿è¡æ­¤èæ¬ï¼"
fi

# ---------- æ´æ° Termux ----------
info "æ´æ° Termux åç®¡çå¨..."
TERM=noninteractive pkg update -y > /dev/null 2>&1
TERM=noninteractive pkg upgrade -y > /dev/null 2>&1
ok "Termux æ´æ°å®æ"

# ---------- å®è£ proot-distro ----------
info "å®è£ proot-distro..."
pkg install proot-distro -y
ok "proot-distro å®è£å®æ"

# ---------- å®è£ Ubuntu ----------
if proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
    warn "Ubuntu å·²å®è£ï¼è·³è¿"
else
    info "å®è£ Ubuntuï¼å¯è½éè¦å åéï¼..."
    proot-distro install ubuntu
    ok "Ubuntu å®è£å®æ"
fi

# ---------- Ubuntu åé¨å®è£ ----------
info "è¿å¥ Ubuntu å®è£ SearXNG..."

proot-distro login ubuntu -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive

echo "[ä¿¡æ¯] æ´æ° Ubuntu..."
apt update -y > /dev/null 2>&1

echo "[ä¿¡æ¯] å®è£ç¼è¯ä¾èµ..."
apt install -y -o Dpkg::Options::="--force-confold" \
    python3 python3-pip python3-venv python3-dev \
    git build-essential libxml2-dev libxslt1-dev \
    libffi-dev libssl-dev zlib1g-dev libjpeg-dev libyaml-dev > /dev/null 2>&1
echo "[æå] ä¾èµå®è£å®æ"

echo "[ä¿¡æ¯] åå»º Python èæç¯å¢..."
cd ~
python3 -m venv ~/searxng-env
source ~/searxng-env/bin/activate

echo "[ä¿¡æ¯] åçº§ pip..."
pip install --upgrade pip setuptools wheel > /dev/null 2>&1

if [ -d ~/searxng ]; then
    echo "[æ³¨æ] SearXNG ç®å½å·²å­å¨ï¼è·³è¿åé"
    cd ~/searxng
    git pull > /dev/null 2>&1 || true
else
    echo "[ä¿¡æ¯] åé SearXNG..."
    git clone https://github.com/searxng/searxng.git ~/searxng
fi

echo "[ä¿¡æ¯] å®è£ Python ä¾èµ..."
pip install -r ~/searxng/requirements.txt > /dev/null 2>&1
pip install -r ~/searxng/requirements-server.txt > /dev/null 2>&1

echo "[ä¿¡æ¯] å®è£ SearXNG æ¬ä½..."
pip install --no-build-isolation ~/searxng > /dev/null 2>&1
echo "[æå] SearXNG å®è£å®æ"

echo "[ä¿¡æ¯] ä¿®å¤å·²ç¥ Bug..."
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
echo "[æå] Bug ä¿®å¤å®æ"

echo "[ä¿¡æ¯] åå¥éç½®æä»¶..."
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
YAML

echo "[æå] éç½®åå¥å®æ"

echo "[ä¿¡æ¯] éªè¯å®è£..."
python3 -c "import searx; print('[æå] SearXNG å¯¼å¥éªè¯éè¿')"
'

# ---------- é¨ç½²å¼æç®¡çå¨ ----------
info "é¨ç½²å¼æç®¡çå¨..."

cat > /tmp/engine_mgr.py << 'PYEOF'
#!/usr/bin/env python3
"""SearXNG Engine Manager"""
import yaml
import os
import shutil
from datetime import datetime

SETTINGS = os.path.expanduser("~/searxng/searx/settings.yml")

ENGINE_LIST = [
    ("baidu", "baidu", "ç¾åº¦", "ä¸­å½æç´¢å¼æï¼æ éç¿»å¢"),
    ("bing", "bing", "Bing", "å¾®è½¯æç´¢å¼æ"),
    ("duckduckgo", "duckduckgo", "DuckDuckGo", "éç§æç´¢å¼æ"),
    ("google", "google", "Google", "å¨çæµè¡æç´¢å¼æ"),
    ("google images", "google_images", "Google å¾ç", "å¾çæç´¢"),
    ("google news", "google_news", "Google æ°é»", "æ°é»æç´¢"),
    ("google videos", "google_videos", "Google è§é¢", "è§é¢æç´¢"),
    ("google scholar", "google_scholar", "Google å­¦æ¯", "å­¦æ¯è®ºææç´¢"),
    ("wikipedia", "wikipedia", "Wikipedia", "èªç±ç¾ç§å¨ä¹¦"),
    ("wikidata", "wikidata", "Wikidata", "ç»æåç¥è¯åº"),
    ("brave", "brave", "Brave Search", "éç§æç´¢å¼æ"),
    ("startpage", "startpage", "Startpage", "å¿åæç´¢å¼æ"),
    ("moegirl", "moegirl", "èå¨ç¾ç§", "ACG ç¾ç§å¨ä¹¦"),
    ("yahoo", "yahoo", "Yahoo", "éèæç´¢"),
    ("yandex", "yandex", "Yandex", "ä¿ç½æ¯æç´¢å¼æ"),
    ("qwant", "qwant", "Qwant", "æ³å½éç§æç´¢å¼æ"),
    ("ecosia", "ecosia", "Ecosia", "ç¯ä¿æç´¢å¼æ"),
    ("github", "github", "GitHub", "ä»£ç æç®¡å¹³å°æç´¢"),
    ("currency convert", "currency_convert", "è´§å¸è½¬æ¢", "å®æ¶æ±çè½¬æ¢"),
    ("searx instances", "searx_instances", "SearX å®ä¾", "æç´¢å¶ä» SearX å®ä¾"),
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
    print("  SearXNG å¼æç®¡ç")
    print("=" * 60)
    print()
    print(f"  {'#':>3}  {'ç¶æ':<10}  {'åç§°':<16}  {'è¯´æ'}")
    print(f"  {'---':>3}  {'------':<10}  {'----':<16}  {'----'}")
    for i, (name, _module, display, desc) in enumerate(ENGINE_LIST, 1):
        if name in disabled_set:
            status = "â å·²ç¦ç¨"
        else:
            status = "â å·²å¯ç¨"
        print(f"  {i:3d}  {status:<10}  {display:<16}  {desc}")
    print()
    print("  æä½ï¼")
    print("    è¾å¥æ°å­    åæ¢å¯ç¨/ç¦ç¨")
    print("    all         å¯ç¨åè¡¨ä¸­å¨é¨å¼æ")
    print("    none        ç¦ç¨åè¡¨ä¸­å¨é¨å¼æ")
    print("    reset       æ¢å¤é»è®¤éç½®")
    print("    0           è¿åä¸çº§èå")
    print()


def main():
    try:
        while True:
            settings = load_settings()
            disabled_set = get_disabled_set(settings)
            show_menu(disabled_set)

            choice = input("  è¯·éæ©: ").strip().lower()

            if choice == "0":
                print("  å·²è¿åä¸»èå")
                break
            elif choice == "all":
                settings = load_settings()
                engines = [
                    e for e in settings.get("engines", [])
                    if not (isinstance(e, dict) and e.get("name") in ENGINE_MAP)
                ]
                settings["engines"] = engines
                save_settings(settings)
                print("  å·²å¯ç¨å¨é¨å¼æ")
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
                print("  å·²ç¦ç¨å¨é¨å¼æ")
            elif choice == "reset":
                settings = load_settings()
                engines = [
                    e for e in settings.get("engines", [])
                    if not (isinstance(e, dict) and e.get("name") in ENGINE_MAP)
                ]
                settings["engines"] = engines
                save_settings(settings)
                print("  å·²æ¢å¤é»è®¤éç½®")
            elif choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(ENGINE_LIST):
                    name, module, display, _ = ENGINE_LIST[idx]
                    settings = load_settings()
                    disabled_set = get_disabled_set(settings)
                    if name in disabled_set:
                        set_engine_disabled(settings, name, False)
                        save_settings(settings)
                        print(f"  å·²å¯ç¨: {display}")
                    else:
                        set_engine_disabled(settings, name, True)
                        save_settings(settings)
                        print(f"  å·²ç¦ç¨: {display}")
                else:
                    print("  æ æéæ©ï¼è¯·éæ°è¾å¥")
            else:
                print("  æ æéæ©ï¼è¯·éæ°è¾å¥")
    except KeyboardInterrupt:
        print("\n  å·²è¿åä¸»èå")


if __name__ == "__main__":
    main()
PYEOF

cp /tmp/engine_mgr.py "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/root/searxng/engine_mgr.py"
rm -f /tmp/engine_mgr.py
ok "å¼æç®¡çå¨é¨ç½²å®æ"

# ---------- åå»ºä¸»èåèæ¬ ----------
info "åå»ºä¸»èåèæ¬..."

cat > ~/sear << 'MENU_EOF'
#!/bin/bash
LOG_DIR=~/searxng-logs
mkdir -p "$LOG_DIR"

start_searxng() {
    local logfile="$LOG_DIR/searxng_$(date +%Y%m%d_%H%M%S).log"
    echo ""
    echo "  æ¥å¿æä»¶: $logfile"
    proot-distro login ubuntu -- bash -c "
        source ~/searxng-env/bin/activate
        export SEARXNG_SETTINGS_PATH=~/searxng/searx/settings.yml
        cd ~/searxng
        echo ''
        echo '================================'
        echo '  SearXNG å·²å¯å¨'
        echo '  è®¿é®å°å: http://localhost:8888'
        echo '  æ Ctrl+C åæ­¢æå¡'
        echo '================================'
        echo ''
        python3 -m searx.webapp 2>&1
    " | tee "$logfile"
}

view_logs() {
    echo ""
    echo "================================"
    echo "  æ¥å¿æ¥ç"
    echo "================================"
    echo ""

    logfiles=($(ls -t "$LOG_DIR"/searxng_*.log 2>/dev/null))

    if [ ${#logfiles[@]} -eq 0 ]; then
        echo "  ææ æ¥å¿æä»¶"
        echo "  ï¼éè¦åå¯å¨ä¸æ¬¡ SearXNG æä¼äº§çæ¥å¿ï¼"
        return
    fi

    echo "  å¯ç¨æ¥å¿æä»¶ï¼"
    echo ""
    for i in "${!logfiles[@]}"; do
        local fname=$(basename "${logfiles[$i]}")
        local fsize=$(du -h "${logfiles[$i]}" | cut -f1)
        local lines=$(wc -l < "${logfiles[$i]}")
        echo "  $((i+1)). $fname  ($fsize, ${lines}è¡)"
    done
    echo ""
    echo "  æä½ï¼"
    echo "    è¾å¥æ°å­      æ¥çè¯¥æ¥å¿"
    echo "    s + å³é®è¯    æç´¢æ¥å¿ï¼å¦ s baiduï¼"
    echo "    e             æ¥çææéè¯¯æ¥å¿"
    echo "    t             æ¥çæè¿30æ¡æ¥å¿"
    echo "    c             æ¸ç©ºæææ¥å¿"
    echo "    0             è¿å"
    echo ""
    read -p "  è¯·éæ©: " log_choice

    case $log_choice in
        0)
            return
            ;;
        e)
            echo ""
            echo "  ========== ææéè¯¯æ¥å¿ =========="
            echo ""
            grep -i -n "error\|traceback\|exception\|fail" "$LOG_DIR"/searxng_*.log 2>/dev/null || echo "  æ²¡ææ¾å°éè¯¯æ¥å¿"
            echo ""
            ;;
        t)
            echo ""
            echo "  ========== æè¿30æ¡æ¥å¿ =========="
            echo ""
            tail -30 "$LOG_DIR"/searxng_*.log 2>/dev/null | tail -30
            echo ""
            ;;
        c)
            read -p "  ç¡®å®è¦æ¸ç©ºæææ¥å¿åï¼(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -f "$LOG_DIR"/searxng_*.log
                echo "  æ¥å¿å·²æ¸ç©º"
            fi
            ;;
        s*)
            local keyword="${log_choice#s }"
            keyword=$(echo "$keyword" | xargs)
            if [ -z "$keyword" ]; then
                read -p "  è¯·è¾å¥æç´¢å³é®è¯: " keyword
            fi
            echo ""
            echo "  ========== æç´¢: $keyword =========="
            echo ""
            grep -i -n "$keyword" "$LOG_DIR"/searxng_*.log 2>/dev/null || echo "  æ²¡ææ¾å°å¹éåå®¹"
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
                echo "  æ æéæ©"
            fi
            ;;
        *)
            echo "  æ æéæ©"
            ;;
    esac
}

while true; do
    echo ""
    echo "================================"
    echo "  SearXNG æç´¢å¼æç®¡ç"
    echo "================================"
    echo ""
    echo "  1. å¯å¨ SearXNG"
    echo "  2. å¼æç®¡ç"
    echo "  3. æ¥çå½åéç½®"
    echo "  4. ç¼è¾éç½®æä»¶"
    echo "  5. æ¥çæ¥å¿"
    echo "  6. å¸è½½ SearXNG"
    echo "  0. éåº"
    echo ""
    read -p "  è¯·éæ© [0-6]: " choice
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
                echo "  ç¨æ³ï¼i ç¼è¾  Esc+:wq ä¿å­  Esc+:q! éåº"
                echo ""
                vi ~/searxng/searx/settings.yml
            '
            ;;
        5)
            view_logs
            ;;
        6)
            echo ""
            read -p "  ç¡®å®è¦å¸è½½ SearXNG åï¼(y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                echo "  æ­£å¨å¸è½½..."
                proot-distro remove ubuntu 2>/dev/null
                rm -f ~/sear
                rm -rf "$LOG_DIR"
                echo "  å¸è½½å®æï¼"
                exit 0
            else
                echo "  åæ¶å¸è½½"
            fi
            ;;
        0)
            echo "  åè§ï¼"
            exit 0
            ;;
        *)
            echo "  æ æéæ©ï¼è¯·éæ°è¾å¥"
            ;;
    esac
done
MENU_EOF

chmod +x ~/sear
ok "ä¸»èåèæ¬åå»ºå®æ"

# ---------- å®æ ----------
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  å®è£å¨é¨å®æï¼${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "  å¯å¨æ¹å¼ï¼${CYAN}~/sear${NC}"
echo -e "  æµè§å¨è®¿é®ï¼${CYAN}http://localhost:8888${NC}"
echo ""
