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