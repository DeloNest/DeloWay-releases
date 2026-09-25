"""Shared by DeloWay's Python helpers: where deloway.json lives and what it says.

The shell's language setting (system.uiLanguage) is the language of every message a
helper shows, not the process locale: LANG can still be English while the shell is
Arabic (the locale only follows after a re-login, and only if it is generated).
"""
import json
import os


def config_path() -> str:
    return os.environ.get("DELOWAY_CONFIG") or os.path.expanduser("~/.config/deloway/deloway.json")


def load_config() -> dict:
    try:
        with open(config_path(), "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def ui_language() -> str:
    lang = (load_config().get("system") or {}).get("uiLanguage")
    return lang if lang in ("ar", "en") else "en"


def tr(en: str, ar: str) -> str:
    """The message in the shell's language."""
    return ar if ui_language() == "ar" else en
