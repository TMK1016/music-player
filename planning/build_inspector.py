"""Build the offline planning inspector. No network or third-party packages."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
data = json.loads((ROOT / "flow.json").read_text())
journal = json.loads((ROOT / "changelog.json").read_text())
payload = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c")
template = (ROOT / "inspector-template.html").read_text()
assert template.count("__PLAN_JSON__") == 1
assert template.count("__CHANGELOG_JSON__") == 1
technical = json.loads((ROOT / "eq-technical.json").read_text())
html = template.replace("__EQ_TECHNICAL_PANEL__", (ROOT / "eq-technical-panel.html").read_text()).replace("__EQ_TECHNICAL_JSON__", json.dumps(technical, ensure_ascii=False).replace("<", "\\u003c"))
html = html.replace("__PLAN_JSON__", payload).replace("__CHANGELOG_JSON__", json.dumps(journal, ensure_ascii=False).replace("<", "\\u003c"))
html = html.replace("__ANNOTATIONS_JS__", (ROOT / "inspector-annotations.js").read_text())
pm = json.loads((ROOT / "pm-plan.json").read_text())
html = html.replace("__PM_JSON__", json.dumps(pm, ensure_ascii=False).replace("<", "\\u003c")).replace("__PM_PANEL_JS__", (ROOT / "pm-panel.js").read_text())
(ROOT / "flow-inspector.html").write_text(html)
print(f"Built flow-inspector.html: {len(data['nodes'])} nodes / {len(journal['entries'])} journal entries")
