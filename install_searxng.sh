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

SEARXNG_FLAGS="$HOME/.searxng_installed"
mkdir -p "$SEARXNG_FLAGS"

# ---------- 更新 Termux ----------
info "检查 Termux 包管理器..."
if [ -f $HOME/.searxng_installed/.termux_updated ]; then
    skip "Termux 已更新，跳过"
else
    info "更新 Termux 包管理器..."
    TERM=noninteractive pkg update -y
    TERM=noninteractive pkg upgrade -y
    touch $HOME/.searxng_installed/.termux_updated
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
INSTALL_OUTPUT=$(proot-distro install ubuntu 2>&1) && {
    ok "Ubuntu 安装完成"
} || {
    if echo "$INSTALL_OUTPUT" | grep -qi "already exists"; then
        skip "Ubuntu 已安装，跳过"
    else
        echo "$INSTALL_OUTPUT"
        fail "Ubuntu 安装失败"
    fi
}

# ---------- Ubuntu 内部安装 ----------
info "进入 Ubuntu 检查 SearXNG 安装状态..."

echo "c2V0IC1lCmV4cG9ydCBERUJJQU5fRlJPTlRFTkQ9bm9uaW50ZXJhY3RpdmUKCiMg5qOA5p+l5qCH5b+X5paH5Lu2ClNFQVJYTkdfRE9ORT0iL3RtcC8uc2VhcnhuZ19pbnN0YWxsX2RvbmUiCgppZiBbIC1mICIkU0VBUlhOR19ET05FIiBdOyB0aGVuCiAgICBlY2hvICJb6Lez6L+HXSBTZWFyWE5HIOW3suWuieijheWujOaIkO+8jOi3s+i/h+aJgOaciSBVYnVudHUg5YaF6YOo5q2l6aqkIgogICAgZXhpdCAwCmZpCgojIC0tLSDmm7TmlrAgVWJ1bnR1IC0tLQplY2hvICJb5L+h5oGvXSDmo4Dmn6UgVWJ1bnR1IOWMheeuoeeQhuWZqC4uLiIKaWYgWyAtZiAvdG1wLy5zZWFyeG5nX2FwdF91cGRhdGVkIF07IHRoZW4KICAgIGVjaG8gIlvot7Pov4ddIFVidW50dSDlt7Lmm7TmlrDvvIzot7Pov4ciCmVsc2UKICAgIGVjaG8gIlvkv6Hmga9dIOabtOaWsCBVYnVudHUuLi4iCiAgICBhcHQgdXBkYXRlIC15CiAgICB0b3VjaCAvdG1wLy5zZWFyeG5nX2FwdF91cGRhdGVkCiAgICBlY2hvICJb5oiQ5YqfXSBVYnVudHUg5pu05paw5a6M5oiQIgpmaQoKIyAtLS0g5a6J6KOF57yW6K+R5L6d6LWWIC0tLQplY2hvICJb5L+h5oGvXSDmo4Dmn6XnvJbor5Hkvp3otZYuLi4iCk5FRURFRD0icHl0aG9uMyBweXRob24zLXBpcCBweXRob24zLXZlbnYgcHl0aG9uMy1kZXYgZ2l0IGJ1aWxkLWVzc2VudGlhbCBsaWJ4bWwyLWRldiBsaWJ4c2x0MS1kZXYgbGliZmZpLWRldiBsaWJzc2wtZGV2IHpsaWIxZy1kZXYgbGlianBlZy1kZXYgbGlieWFtbC1kZXYiCk1JU1NJTkc9IiIKZm9yIHBrZyBpbiAkTkVFREVEOyBkbwogICAgaWYgISBkcGtnIC1zICIkcGtnIiAmPi9kZXYvbnVsbDsgdGhlbgogICAgICAgIE1JU1NJTkc9IiRNSVNTSU5HICRwa2ciCiAgICBmaQpkb25lCgppZiBbIC16ICIkTUlTU0lORyIgXTsgdGhlbgogICAgZWNobyAiW+i3s+i/h10g57yW6K+R5L6d6LWW5bey5YWo6YOo5a6J6KOF77yM6Lez6L+HIgplbHNlCiAgICBlY2hvICJb5L+h5oGvXSDlronoo4XnvLrlpLHkvp3otZY6JE1JU1NJTkciCiAgICBhcHQgaW5zdGFsbCAteSAtbyBEcGtnOjpPcHRpb25zOjo9Ii0tZm9yY2UtY29uZm9sZCIgJE1JU1NJTkcKICAgIGVjaG8gIlvmiJDlip9dIOS+nei1luWuieijheWujOaIkCIKZmkKCiMgLS0tIOWIm+W7uiBQeXRob24g6Jma5ouf546v5aKDIC0tLQplY2hvICJb5L+h5oGvXSDmo4Dmn6UgUHl0aG9uIOiZmuaLn+eOr+Wigy4uLiIKaWYgWyAtZCB+L3NlYXJ4bmctZW52IF0gJiYgWyAtZiB+L3NlYXJ4bmctZW52L2Jpbi9hY3RpdmF0ZSBdOyB0aGVuCiAgICBlY2hvICJb6Lez6L+HXSDomZrmi5/njq/looPlt7LlrZjlnKjvvIzot7Pov4ciCmVsc2UKICAgIGVjaG8gIlvkv6Hmga9dIOWIm+W7uiBQeXRob24g6Jma5ouf546v5aKDLi4uIgogICAgY2QgfgogICAgcHl0aG9uMyAtbSB2ZW52IH4vc2VhcnhuZy1lbnYKICAgIGVjaG8gIlvmiJDlip9dIOiZmuaLn+eOr+Wig+WIm+W7uuWujOaIkCIKZmkKc291cmNlIH4vc2VhcnhuZy1lbnYvYmluL2FjdGl2YXRlCgojIC0tLSDljYfnuqcgcGlwIC0tLQplY2hvICJb5L+h5oGvXSDmo4Dmn6UgcGlwIOeJiOacrC4uLiIKQ1VSUkVOVF9QSVA9JChwaXAgLS12ZXJzaW9uIDI+L2Rldi9udWxsIHwgYXdrICJ7cHJpbnQgXCQyfSIpCnBpcCBpbnN0YWxsIC0tdXBncmFkZSBwaXAgc2V0dXB0b29scyB3aGVlbAplY2hvICJb5oiQ5YqfXSBwaXAg5bey5piv5pyA5pawIgoKIyAtLS0g5YWL6ZqGIFNlYXJYTkcgLS0tCmVjaG8gIlvkv6Hmga9dIOajgOafpSBTZWFyWE5HIOa6kOeggS4uLiIKaWYgWyAtZCB+L3NlYXJ4bmcgXSAmJiBbIC1mIH4vc2VhcnhuZy9zZXR1cC5weSBdOyB0aGVuCiAgICBlY2hvICJb6Lez6L+HXSBTZWFyWE5HIOebruW9leW3suWtmOWcqO+8jOi3s+i/h+WFi+mahiIKICAgIGNkIH4vc2VhcnhuZwogICAgZ2l0IHB1bGwgfHwgdHJ1ZQplbHNlCiAgICBlY2hvICJb5L+h5oGvXSDlhYvpmoYgU2VhclhORy4uLiIKICAgIHJtIC1yZiB+L3NlYXJ4bmcKICAgIGdpdCBjbG9uZSBodHRwczovL2dpdGh1Yi5jb20vc2VhcnhuZy9zZWFyeG5nLmdpdCB+L3NlYXJ4bmcKICAgIGVjaG8gIlvmiJDlip9dIOWFi+mahuWujOaIkCIKZmkKCiMgLS0tIOWuieijhSBQeXRob24g5L6d6LWWIC0tLQplY2hvICJb5L+h5oGvXSDmo4Dmn6UgUHl0aG9uIOS+nei1li4uLiIKaWYgcHl0aG9uMyAtYyAiaW1wb3J0IGx4bWwsIHlhbWwsIGZsYXNrIiAyPi9kZXYvbnVsbDsgdGhlbgogICAgZWNobyAiW+i3s+i/h10gUHl0aG9uIOS+nei1luW3suWuieijhe+8jOi3s+i/hyIKZWxzZQogICAgZWNobyAiW+S/oeaBr10g5a6J6KOFIFB5dGhvbiDkvp3otZYuLi4iCiAgICBwaXAgaW5zdGFsbCAtciB+L3NlYXJ4bmcvcmVxdWlyZW1lbnRzLnR4dAogICAgcGlwIGluc3RhbGwgLXIgfi9zZWFyeG5nL3JlcXVpcmVtZW50cy1zZXJ2ZXIudHh0CiAgICBlY2hvICJb5oiQ5YqfXSBQeXRob24g5L6d6LWW5a6J6KOF5a6M5oiQIgpmaQoKIyAtLS0g5a6J6KOFIFNlYXJYTkcg5pys5L2TIC0tLQplY2hvICJb5L+h5oGvXSDmo4Dmn6UgU2VhclhORyDmnKzkvZMuLi4iCmlmIHB5dGhvbjMgLWMgImltcG9ydCBzZWFyeCIgMj4vZGV2L251bGw7IHRoZW4KICAgIGVjaG8gIlvot7Pov4ddIFNlYXJYTkcg5pys5L2T5bey5a6J6KOF77yM6Lez6L+HIgplbHNlCiAgICBlY2hvICJb5L+h5oGvXSDlronoo4UgU2VhclhORyDmnKzkvZMuLi4iCiAgICBwaXAgaW5zdGFsbCAtLW5vLWJ1aWxkLWlzb2xhdGlvbiB+L3NlYXJ4bmcKICAgIGVjaG8gIlvmiJDlip9dIFNlYXJYTkcg5a6J6KOF5a6M5oiQIgpmaQoKIyAtLS0g5L+u5aSN5bey55+lIEJ1ZyAtLS0KZWNobyAiW+S/oeaBr10g5qOA5p+lIEJ1ZyDkv67lpI0uLi4iCmlmIGdyZXAgLXEgImRlZmF1bHRfZG9pX3Jlc29sdmVyIiB+L3NlYXJ4bmcvc2Vhcngvc2V0dGluZ3NfZGVmYXVsdHMucHkgMj4vZGV2L251bGw7IHRoZW4KICAgIGVjaG8gIlvot7Pov4ddIEJ1ZyDlt7Lkv67lpI3vvIzot7Pov4ciCmVsc2UKICAgIGVjaG8gIlvkv6Hmga9dIOS/ruWkjeW3suefpSBCdWcuLi4iCiAgICBweXRob24zIDw8IFBZRklYCndpdGggb3BlbigiL3Jvb3Qvc2VhcnhuZy9zZWFyeC9zZXR0aW5nc19kZWZhdWx0cy5weSIsICJyIikgYXMgZjoKICAgIGMgPSBmLnJlYWQoKQppZiAiZGVmYXVsdF9kb2lfcmVzb2x2ZXIiIG5vdCBpbiBjOgogICAgYyA9IGMucmVwbGFjZSgKICAgICAgICAiJ2RvaV9yZXNvbHZlcnMnOiB7fSwiLAogICAgICAgICInZG9pX3Jlc29sdmVycyc6IHtcIm9hZG9pLm9yZ1wiOiBcImh0dHBzOi8vZG9pLm9yZy9cIn0sXG4gICAgXCJkZWZhdWx0X2RvaV9yZXNvbHZlclwiOiBcIm9hZG9pLm9yZ1wiLCIKICAgICkKd2l0aCBvcGVuKCIvcm9vdC9zZWFyeG5nL3NlYXJ4L3NldHRpbmdzX2RlZmF1bHRzLnB5IiwgInciKSBhcyBmOgogICAgZi53cml0ZShjKQpQWUZJWAogICAgZWNobyAiW+aIkOWKn10gQnVnIOS/ruWkjeWujOaIkCIKZmkKCiMgLS0tIOWGmeWFpemFjee9ruaWh+S7tiAtLS0KZWNobyAiW+S/oeaBr10g5qOA5p+l6YWN572u5paH5Lu2Li4uIgppZiBbIC1mIH4vc2VhcnhuZy9zZWFyeC9zZXR0aW5ncy55bWwgXTsgdGhlbgogICAgZWNobyAiW+i3s+i/h10g6YWN572u5paH5Lu25bey5a2Y5Zyo77yM6Lez6L+HIgplbHNlCiAgICBlY2hvICJb5L+h5oGvXSDlhpnlhaXphY3nva7mlofku7YuLi4iCiAgICBta2RpciAtcCB+L3NlYXJ4bmcvc2VhcngKCiAgICBTSz0kKHB5dGhvbjMgLWMgImltcG9ydCBzZWNyZXRzOyBwcmludChzZWNyZXRzLnRva2VuX2hleCgzMikpIikKCiAgICBjYXQgPiB+L3NlYXJ4bmcvc2Vhcngvc2V0dGluZ3MueW1sIDw8IFlBTUwKdXNlX2RlZmF1bHRfc2V0dGluZ3M6IHRydWUKZ2VuZXJhbDoKICBpbnN0YW5jZV9uYW1lOiAiU2VhclhORyIKICBkZWJ1ZzogZmFsc2UKCnNlYXJjaDoKICBzYWZlX3NlYXJjaDogMAogIGF1dG9jb21wbGV0ZTogIiIKICBkZWZhdWx0X2xhbmc6ICJ6aC1DTiIKICBmb3JtYXRzOgogICAgLSBodG1sCiAgICAtIGpzb24KCnNlcnZlcjoKICBzZWNyZXRfa2V5OiAiXCR7U0t9IgogIGJpbmRfYWRkcmVzczogIjAuMC4wLjAiCiAgcG9ydDogODg4OAogIGxpbWl0ZXI6IGZhbHNlCiAgaW1hZ2VfcHJveHk6IGZhbHNlCiAgcHVibGljX2luc3RhbmNlOiBmYWxzZQogIGRlZmF1bHRfaHR0cF9oZWFkZXJzOgogICAgWC1Db250ZW50LVR5cGUtT3B0aW9uczogbm9zbmlmZgogICAgWC1Eb3dubG9hZC1PcHRpb25zOiBub29wZW4KICAgIFgtUm9ib3RzLVRhZzogbm9pbmRleCwgbm9mb2xsb3cKICAgIFJlZmVycmVyLVBvbGljeTogbm8tcmVmZXJyZXIKICAgIEFjY2Vzcy1Db250cm9sLUFsbG93LU9yaWdpbjogIioiCiAgICBBY2Nlc3MtQ29udHJvbC1BbGxvdy1NZXRob2RzOiAiR0VULCBQT1NUIgogICAgQWNjZXNzLUNvbnRyb2wtQWxsb3ctSGVhZGVyczogIioiCgp1aToKICBzdGF0aWNfdXNlX2hhc2g6IHRydWUKCm91dGdvaW5nOgogIHJlcXVlc3RfdGltZW91dDogMTAuMApZQU1MCiAgICBlY2hvICJb5oiQ5YqfXSDphY3nva7lhpnlhaXlrozmiJAiCmZpCgojIC0tLSDpqozor4Hlronoo4UgLS0tCmVjaG8gIlvkv6Hmga9dIOmqjOivgeWuieijhS4uLiIKcHl0aG9uMyAtYyAiaW1wb3J0IHNlYXJ4OyBwcmludCgnU2VhclhORyBPSycpIgoKIyDmoIforrDlhajpg6jlrozmiJAKdG91Y2ggIiRTRUFSWE5HX0RPTkUiCmVjaG8gIlvmiJDlip9dIFVidW50dSDlhoXpg6jlronoo4Xlhajpg6jlrozmiJAi" | base64 -d > /tmp/_searxng_install.sh

proot-distro login ubuntu -- bash /tmp/_searxng_install.sh
rm -f /tmp/_searxng_install.sh

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
