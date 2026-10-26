"""Check graph integrity and ensure the generated inspector matches flow.json."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent
plan = json.loads((root / "flow.json").read_text())
nodes = plan["nodes"]
by_id = {n["id"]: n for n in nodes}
assert len(by_id) == len(nodes), "Duplicate node IDs"
allowed = {"規劃中", "等待確認", "條件式", "待授權", "介面完成", "部分實作", "已移除"}
for n in nodes:
    assert 0 <= n["stage"] < len(plan["stages"])
    assert n["status"] in allowed
    assert n["acceptance"] and n["planned_paths"]
    if n["status"] in {"介面完成", "部分實作", "已移除"}:
        assert n["evidence"] and n["implemented_paths"]
        for path in n["evidence"] + n["implemented_paths"]:
            assert (root.parent / path).exists(), f"Missing evidence or implementation: {path}"
    else:
        assert n["evidence"] == [], "Unimplemented audio nodes must not imply runtime evidence"
    for dep in n["depends_on"]:
        assert dep in by_id and dep != n["id"], (n["id"], dep)
        assert by_id[dep]["stage"] <= n["stage"], "Backwards phase dependency"
visiting, visited = set(), set()
def visit(key):
    assert key not in visiting, f"Cycle at {key}"
    if key in visited:
        return
    visiting.add(key)
    for dep in by_id[key]["depends_on"]:
        visit(dep)
    visiting.remove(key)
    visited.add(key)
for key in by_id:
    visit(key)
assert not any("YT-01" in n["depends_on"] for n in nodes), "YT must not block MVP"
html = (root / "flow-inspector.html").read_text()
embedded = re.search(r'<script id="plan-data" type="application/json">(.*?)</script>', html, re.S)
assert embedded and json.loads(embedded.group(1)) == plan, "Rebuild inspector"
journal = json.loads((root / "changelog.json").read_text())
assert journal["schema_version"] == 1 and journal["entries"]
journal_embedded = re.search(r'<script id="journal-data" type="application/json">(.*?)</script>', html, re.S)
assert journal_embedded and json.loads(journal_embedded.group(1)) == journal, "Rebuild inspector journal"
native_copy = root.parent / "apps/apple/Resources/changelog.json"
assert native_copy.exists() and json.loads(native_copy.read_text()) == journal, "Run scripts/generate_xcode_project.py to sync native journal"
release_ids, change_ids = set(), set()
workspace = root.parents[2]
destinations = {None, "settings", "player", "library", "equalizer", "vehicle", "developmentLog"}
for release in journal["entries"]:
    assert release["id"] not in release_ids
    release_ids.add(release["id"])
    assert release["version"] and release["summary"] and release["changes"]
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}", release["date"])
    for change in release["changes"]:
        assert change["id"] not in change_ids, "Change IDs must remain globally unique"
        change_ids.add(change["id"])
        assert change["title"] and change["summary"] and change["node_ids"] and change["locations"]
        assert all(node in by_id for node in change["node_ids"]), f"Unknown journal node: {change['id']}"
        assert change.get("target_page") in destinations, f"Unknown app destination: {change['id']}"
        for location in change["locations"]:
            target = (root.parent / location["path"]).resolve()
            assert target.is_relative_to(workspace) and target.is_file(), f"Invalid journal location: {location['path']}"
scripts = re.findall(r'<script>(.*?)</script>', html, re.S)
Path("/private/tmp/orca-inspector-check.js").write_text("\n".join(scripts))
print(f"PASS: {len(nodes)} unique nodes, acyclic dependencies, valid planning states, embedded data matches")
print(f"PASS: {len(release_ids)} journal entries / {len(change_ids)} changes; node/file destinations valid; HTML and native journal copies match")
print("JavaScript syntax: node --check /private/tmp/orca-inspector-check.js")

technical = json.loads((root / "eq-technical.json").read_text())
source = json.loads((root / "eq-technical-source.json").read_text())
tech_embedded = re.search(r'<script id="eq-technical-data" type="application/json">(.*?)</script>', html, re.S)
assert tech_embedded and json.loads(tech_embedded.group(1)) == technical, "Rebuild technical panel"
assert len(technical["examples"]) == len(source["examples"])
for before, after in zip(source["examples"], technical["examples"]):
    assert all(after[k] == v for k, v in before.items()), "Regenerate technical examples"
    assert len(after["curve"]) == 181 and -96 <= after["new_gain"] <= 0
assert technical["solutions"] == source["solutions"]
assert technical["selected_solution"] == "A"
assert "__EQ_TECHNICAL" not in html
print("PASS: technical section, shared-estimator examples and embedded data match")


pm = json.loads((root / "pm-plan.json").read_text())
embedded_pm = re.search(r'<script id="pm-data" type="application/json">(.*?)</script>', html, re.S)
assert embedded_pm and json.loads(embedded_pm.group(1)) == pm
items = {item["id"]: item for item in pm["items"]}
assert len(items) == len(pm["items"])
seen_pm, visiting_pm = set(), set()
def visit_pm(key):
    assert key not in visiting_pm, "PM dependency cycle"
    if key in seen_pm: return
    visiting_pm.add(key)
    for dep in items[key]["depends_on"]:
        assert dep in items
        visit_pm(dep)
    visiting_pm.remove(key); seen_pm.add(key)
for item in pm["items"]:
    assert item["acceptance"] and item["story"] and all(n in by_id for n in item["node_ids"])
    visit_pm(item["id"])
assert sorted(i["rank"] for i in pm["items"] if i["rank"] is not None) == [1,2,3,4,5]
assert (root / pm["source_skill"]).is_file()
print(f"PASS: {len(items)} PM items, valid engineering mappings, priority ranks and acyclic dependencies; embedded PM data matches")
