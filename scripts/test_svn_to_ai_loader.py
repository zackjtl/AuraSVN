import json

import svn_to_ai_loader as loader


SAMPLE_XML = """<log>
  <logentry revision="1250">
    <author>eti</author>
    <date>2026-05-12T03:00:00.000000Z</date>
    <paths>
      <path action="A" copyfrom-path="/trunk" copyfrom-rev="1249">/branches/feat_sd_controller</path>
      <path action="M">/trunk/a.py</path>
    </paths>
    <msg>ABC-123
Merged revision 1248 from /trunk
Fix controller</msg>
  </logentry>
</log>"""


def test_parse_entries_and_topology():
    entries, events = loader.parse_log_entries(SAMPLE_XML, r"([A-Z]+-\d+)")
    topology = {}
    loader.update_topology(topology, events)

    assert len(entries) == 1
    assert len(events) == 1
    assert entries[0]["ticket_id"] == "ABC-123"
    assert "Merged revision" not in entries[0]["message"]

    changed_paths = json.loads(entries[0]["changed_paths"])
    assert changed_paths[0]["copyfrom_path"] == "/trunk"
    assert topology["/branches/feat_sd_controller"]["parent"] == "/trunk"
    assert topology["/trunk"]["children"] == ["/branches/feat_sd_controller"]


if __name__ == "__main__":
    test_parse_entries_and_topology()
    print("smoke test passed")
