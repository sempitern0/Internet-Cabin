#!/usr/bin/env python3
"""Validate cabin authoring contracts before importing or exporting the game."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALIASES = {
    "@overview": {"overview_open", "overview_closed"},
    "@interior_door": {"door_open", "door_closed"},
}


def validate(data, catalog, root=ROOT):
    errors = []

    def require(condition, location, message):
        if not condition:
            errors.append(f"{location}: {message}")
        return condition

    def rect(value, location, bottom=1.0):
        if not require(isinstance(value, list) and len(value) == 4
                       and all(type(v) in (float, int) and math.isfinite(v) for v in value),
                       location, "rect must contain four finite numbers"):
            return
        x, y, w, h = value
        require(x >= 0 and y >= 0 and w > 0 and h > 0
                and x + w <= 1.000001 and y + h <= bottom + 0.000001,
                location, "rect outside usable normalized image")

    def resource(value, location, prefix="res://"):
        if not require(isinstance(value, str) and value.startswith(prefix),
                       location, "invalid resource path"):
            return
        path = (root / value.removeprefix("res://")).resolve()
        require(path.is_relative_to(root.resolve()) and path.is_file(),
                location, f"missing resource: {value}")

    def flags(spec, key, location):
        value = spec.get(key, [])
        valid = isinstance(value, list) and all(isinstance(v, str) and v for v in value)
        require(valid, location, f"{key} must be an array of nonempty flag IDs")
        return set(value) if valid else set()

    if not isinstance(data, dict) or not isinstance(catalog, dict):
        return ["Map and catalog must be JSON objects"]
    require(data.get("schema") == 2, "map", "unsupported schema")
    require(catalog.get("schema") == 1, "catalog", "unsupported schema")
    pages, items = data.get("pages"), catalog.get("items")
    if not isinstance(pages, list) or not isinstance(items, list):
        return errors + ["pages and items must be arrays"]

    def index(entries, kind):
        result = {}
        for entry in entries:
            if not require(isinstance(entry, dict), kind, "entry must be an object"):
                continue
            key = entry.get("id")
            if not require(isinstance(key, str) and bool(key), kind, "missing ID"):
                continue
            require(key not in result, kind, f"duplicate ID: {key}")
            result[key] = entry
        return result

    page_index, item_index = index(pages, "page"), index(items, "item")
    require(data.get("initial_page") in page_index, "map", "unknown initial_page")
    graph = {key: set() for key in page_index}

    def target(value, location, page_id, aliases=True):
        destinations = ALIASES.get(value, {value}) if isinstance(value, str) else set()
        if not aliases and isinstance(value, str) and value.startswith("@"):
            destinations = set()
        require(bool(destinations) and destinations <= page_index.keys(),
                location, f"unknown/unsupported destination: {value}")
        graph[page_id].update(destinations & page_index.keys())

    for page_id, page in page_index.items():
        resource("res://assets/cabin/" + str(page.get("image", "")), page_id)
        target(page.get("back_target"), page_id + "/back_target", page_id)
        for side in ("edge_left", "edge_right"):
            if side in page:
                target(page[side], page_id + "/" + side, page_id)
        hotspots = page.get("hotspots")
        if not require(isinstance(hotspots, list), page_id, "hotspots must be an array"):
            continue
        for hotspot_id, spec in index(hotspots, page_id).items():
            location = page_id + "/" + hotspot_id
            require(not hotspot_id.startswith(("nav:", "pickup:")), location, "reserved ID prefix")
            require(isinstance(spec.get("label"), str) and bool(spec["label"]),
                    location, "missing label")
            require(spec.get("cursor", "inspect") in ("inspect", "interact"),
                    location, "cursor must be inspect or interact")
            rect(spec.get("rect"), location)
            visible = flags(spec, "visible_when", location)
            hidden = flags(spec, "hidden_when", location)
            require(not visible & hidden, location, "contradictory visibility flags")
            require(("target" in spec) != ("action" in spec), location,
                    "choose exactly one target or action")
            if "polygon" in spec:
                polygon = spec["polygon"]
                require(isinstance(polygon, list) and len(polygon) >= 3 and all(
                    isinstance(pt, list) and len(pt) == 2 and all(
                        type(v) in (float, int) and math.isfinite(v) and 0 <= v <= 1
                        for v in pt) for pt in polygon), location, "invalid polygon")
            if "target" in spec:
                target(spec["target"], location, page_id)
            rule = spec.get("action", {})
            if not require(isinstance(rule, dict), location, "action must be an object"):
                continue
            if rule.get("next_screen"):
                target(rule["next_screen"], location, page_id, aliases=False)
            for key in ("required_item", "give_item"):
                if rule.get(key):
                    require(rule[key] in item_index, location, f"unknown {key}")
            require(not rule.get("consume_item") or bool(rule.get("required_item")),
                    location, "consume_item requires required_item")
            for key in ("consume_item", "one_shot"):
                require(type(rule.get(key, False)) is bool, location, f"{key} must be boolean")
            required = flags(rule, "required_flags", location)
            forbidden = flags(rule, "forbidden_flags", location)
            enabled = flags(rule, "set_flags", location)
            cleared = flags(rule, "clear_flags", location)
            require(not required & forbidden and not enabled & cleared,
                    location, "contradictory action flags")
    for item_id, item in item_index.items():
        for key in ("icon", "examine"):
            resource(item.get(key), item_id + "/" + key)
        require(type(item.get("available", True)) is bool, item_id, "available must be boolean")
        require(type(item.get("collectible", True)) is bool, item_id, "collectible must be boolean")
        if item.get("world_texture"):
            resource(item["world_texture"], item_id + "/world_texture")
        start = item.get("start", {})
        if not require(isinstance(start, dict), item_id, "start must be an object"):
            continue
        require(start.get("page") in page_index, item_id, "unknown start page")
        rect(start.get("rect"), item_id, 0.935)
    initial = data.get("initial_page")
    reached, pending = set(), [initial] if initial in graph else []
    while pending:
        current = pending.pop()
        if current not in reached:
            reached.add(current)
            pending.extend(graph[current] - reached)
    require(reached == page_index.keys(), "map", f"unreachable pages: {sorted(page_index.keys()-reached)}")
    return errors


def main():
    try:
        data = json.loads((ROOT / "game/adventure/cabin_map.json").read_text())
        catalog = json.loads((ROOT / "game/inventory/cabin_items.json").read_text())
        errors = validate(data, catalog)
    except (ValueError, OSError) as error:
        errors = [str(error)]
    for error in errors:
        print(error)
    print(f"Cabin content: {'FAIL' if errors else 'PASS'} ({len(errors)} errors)")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
