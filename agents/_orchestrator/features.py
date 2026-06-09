import difflib
import json
from pathlib import Path
from typing import Any, Optional

from .config import FEATURES_DIR, FEATURES_CONFIG, KNOWN_FEATURES, DOMAIN_KEYWORDS, load_features_config, app_features_dir, app_features_config


def _iter_features_dir(app: str = ""):
    base = app_features_dir(app)
    if base.is_dir():
        for entry in base.iterdir():
            if not entry.name.startswith("_"):
                yield entry


def _features_config_for(feature_name: str, domain: str) -> tuple[Path, Path]:
    """Return (features_dir, config_path) for the given feature based on its domain."""
    cfg = load_features_config()
    apps = cfg.get("apps", {})
    for app_name, app_cfg in apps.items():
        for dom in (domain, f"{app_name}/{domain}"):
            if dom in app_cfg.get("domains", []):
                return app_features_dir(app_name), app_features_config(app_name)
    return FEATURES_DIR, FEATURES_CONFIG


def infer_domain_action(feature_name: str) -> tuple[str, str]:
    name = feature_name.strip()
    if name in KNOWN_FEATURES:
        return KNOWN_FEATURES[name], name
    lower = name.lower()
    for key, (domain, action) in DOMAIN_KEYWORDS.items():
        if lower == key or lower == action.lower():
            return domain, action
    for domain_dir in _iter_features_dir():
        if not domain_dir.is_dir():
            continue
        for feature_dir in domain_dir.iterdir():
            if not feature_dir.is_dir() or feature_dir.name.startswith("_"):
                continue
            if feature_dir.name.lower() == lower:
                return domain_dir.name, feature_dir.name
    return "", name


def resolve_feature(request_feature: str) -> Optional[Path]:
    feature_dir = find_feature_dir(request_feature)
    if feature_dir:
        return feature_dir
    return _fuzzy_suggest(request_feature)


def _fuzzy_suggest(request_feature: str) -> Optional[Path]:
    candidates: dict[str, Path] = {}
    for domain_dir in _iter_features_dir():
        if not domain_dir.is_dir():
            continue
        for entry in domain_dir.iterdir():
            if entry.is_dir() and not entry.name.startswith("_"):
                candidates[entry.name] = entry

    matches = difflib.get_close_matches(request_feature, list(candidates.keys()), n=3, cutoff=0.6)
    if not matches:
        return None

    print(f"[Orchestrator] No exact match for '{request_feature}'. Did you mean:")
    for i, m in enumerate(matches, 1):
        print(f"  {i}. {m}")
    print(f"  n. No, cancel")
    choice = input(f"Enter choice [1-{len(matches)} or n]: ").strip().lower()
    if choice == "n":
        return None
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(matches):
            return candidates[matches[idx]]
    except ValueError:
        pass
    return None


def find_feature_dir(request_feature: str) -> Optional[Path]:
    lower = request_feature.lower()

    if request_feature in KNOWN_FEATURES:
        domain = KNOWN_FEATURES[request_feature]
        fdir, _fcfg = _features_config_for(request_feature, domain)
        domain_dir = fdir / domain
        if domain_dir.is_dir():
            if (domain_dir / "Handler.py").exists():
                return domain_dir
            feature_dir = domain_dir / request_feature
            if feature_dir.is_dir():
                return feature_dir

    for domain_dir in _iter_features_dir():
        if not domain_dir.is_dir():
            continue
        if domain_dir.name.lower() == lower:
            if (domain_dir / "Handler.py").exists():
                return domain_dir
        for entry in domain_dir.iterdir():
            if entry.is_dir() and not entry.name.startswith("_"):
                if entry.name.lower() == lower:
                    return entry
    return None


def register_feature_in_json(feature_name: str, domain: str, app: str = "") -> None:
    fdir, fcfg = _features_config_for(feature_name, domain)
    if app:
        fdir, fcfg = app_features_dir(app), app_features_config(app)
    features = (json.loads(fcfg.read_text()) if fcfg.exists()
                else {"known_features": {}, "domain_keywords": {}})
    known = features.setdefault("known_features", {})
    if feature_name not in known:
        known[feature_name] = domain
        keyword = feature_name.lower().replace("feature", "").replace("handler", "").replace("controller", "")
        keywords = features.setdefault("domain_keywords", {})
        if keyword and keyword not in keywords:
            keywords[keyword] = [domain, feature_name]
        with open(fcfg, "w") as f:
            json.dump(features, f, indent=2)
        print(f"[Orchestrator] Registered '{feature_name}' -> '{domain}' in {fcfg.name}")


def unregister_feature_from_json(feature_name: str, feature_dir: Optional[Path] = None, app: str = "") -> None:
    fdir, fcfg = _features_config_for(feature_name, "")
    if app:
        fdir, fcfg = app_features_dir(app), app_features_config(app)
    if not fcfg.exists():
        return False
    features = json.loads(fcfg.read_text())
    known = features.get("known_features", {})
    keywords = features.get("domain_keywords", {})

    candidates = [feature_name]
    if feature_dir:
        candidates.append(feature_dir.name)
    removed = False
    for name in candidates:
        if name in known:
            del known[name]
            removed = True
            stale = [k for k, v in keywords.items() if len(v) >= 2 and v[1] == name]
            for k in stale:
                del keywords[k]
    if removed:
        features["known_features"] = known
        features["domain_keywords"] = keywords
        with open(fcfg, "w") as f:
            json.dump(features, f, indent=2)
        print(f"[Orchestrator] Unregistered '{feature_name}' from {fcfg.name}")
    return removed


def _scan_existing_features(features_dir: Path) -> dict[str, str]:
    features: dict[str, str] = {}
    if not features_dir.is_dir():
        return features
    for domain_dir in features_dir.iterdir():
        if not domain_dir.is_dir() or domain_dir.name.startswith("_"):
            continue
        if (domain_dir / "Handler.py").exists():
            features[domain_dir.name] = domain_dir.name
        else:
            for feature_dir in domain_dir.iterdir():
                if feature_dir.is_dir() and not feature_dir.name.startswith("_"):
                    features[feature_dir.name] = domain_dir.name
    return features
