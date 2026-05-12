import csv
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime


if sys.version_info < (3, 10):
    raise SystemExit(
        "SVN-to-AI Loader 需要 Python 3.10+。目前版本：{0}.{1}.{2}。"
        "Windows 請在 UI 的「Python 指令」填入 py -3.14，或改用 Python 3.10+ 的完整路徑。".format(
            sys.version_info[0],
            sys.version_info[1],
            sys.version_info[2],
        )
    )


DEFAULT_TRUST_ARG = (
    "--trust-server-cert-failures="
    "unknown-ca,cn-mismatch,expired,not-yet-valid,other"
)
CSV_FIELDS = [
    "revision",
    "author",
    "date",
    "ticket_id",
    "message",
    "changed_paths",
]

csv.field_size_limit(1024 * 1024 * 128)


def default_svn_executable():
    tortoise_svn = r"C:\Program Files\TortoiseSVN\bin\svn.exe"
    if os.name == "nt" and os.path.exists(tortoise_svn):
        return tortoise_svn
    return "svn"


def load_config(config_path):
    if not os.path.exists(config_path):
        raise FileNotFoundError(
            "找不到 config 檔案：{0}\n"
            "請先複製 config.example.json 為 config.json 並填入 svn_url。".format(
                config_path
            )
        )

    with open(config_path, "r", encoding="utf-8") as f:
        user_config = json.load(f)

    config = {
        "svn_executable": default_svn_executable(),
        "extra_svn_args": ["--non-interactive", DEFAULT_TRUST_ARG],
        "svn_url": "",
        "username": "",
        "password": "",
        "output_dir": "svn_ai_output",
        "ticket_regex": r"([A-Z][A-Z0-9]+-\d+|[A-Z]{2,}\d{3,}|#\d+)",
        "start_revision": 1,
    }
    config.update(user_config)

    if not config.get("svn_url"):
        raise ValueError("config.json 必須設定 svn_url。")
    if not isinstance(config.get("extra_svn_args"), list):
        raise ValueError("extra_svn_args 必須是字串陣列。")

    return config


def decode_svn_output(data):
    for encoding in ("utf-8", "cp950", "big5"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", errors="replace")


def build_svn_command(config, svn_args):
    command = [config["svn_executable"]]
    command.extend(config.get("extra_svn_args", []))

    username = config.get("username")
    password = config.get("password")
    if username:
        command.extend(["--username", username])
    if password:
        command.extend(["--password", password])

    command.extend(svn_args)
    return command


def run_svn(config, svn_args):
    command = build_svn_command(config, svn_args)
    completed = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=False,
    )

    stdout = decode_svn_output(completed.stdout)
    stderr = decode_svn_output(completed.stderr)
    if completed.returncode != 0:
        raise RuntimeError(
            "SVN 指令失敗，return code={0}\n指令：{1}\n錯誤：{2}".format(
                completed.returncode,
                " ".join(redact_command(command)),
                stderr.strip(),
            )
        )
    return stdout


def redact_command(command):
    redacted = []
    skip_next = False
    for part in command:
        if skip_next:
            redacted.append("******")
            skip_next = False
            continue
        redacted.append(part)
        if part == "--password":
            skip_next = True
    return redacted


def fetch_head_revision(config):
    xml_text = run_svn(config, ["info", "--xml", config["svn_url"]])
    root = ET.fromstring(xml_text)
    revisions = []

    for entry in root.findall(".//entry"):
        revision = parse_int(entry.get("revision"))
        if revision is not None:
            revisions.append(revision)

    for commit in root.findall(".//commit"):
        revision = parse_int(commit.get("revision"))
        if revision is not None:
            revisions.append(revision)

    if not revisions:
        raise RuntimeError("無法從 svn info --xml 取得 HEAD revision。")
    return max(revisions)


def fetch_log_xml(config, start_revision):
    return run_svn(
        config,
        [
            "log",
            "-r",
            "{0}:HEAD".format(start_revision),
            "--xml",
            "-v",
            config["svn_url"],
        ],
    )


def parse_int(value):
    if value is None or value == "":
        return None
    try:
        return int(value)
    except ValueError:
        return None


def normalize_path(path):
    if not path:
        return ""
    path = path.strip()
    if not path.startswith("/"):
        path = "/" + path
    if len(path) > 1:
        path = path.rstrip("/")
    return path


def lineage_root(path):
    normalized = normalize_path(path)
    for marker, kind in (("/branches/", "branch"), ("/tags/", "tag")):
        marker_index = normalized.find(marker)
        if marker_index == -1:
            continue

        name_start = marker_index + len(marker)
        remainder = normalized[name_start:].strip("/")
        if not remainder:
            return None, None

        name = remainder.split("/")[0]
        root_path = normalized[:name_start] + name
        return root_path, kind

    return None, None


def trunk_root(path):
    normalized = normalize_path(path)
    parts = normalized.strip("/").split("/")
    if not parts or parts[0] != "trunk":
        return None
    if len(parts) >= 2:
        return "/trunk/{0}".format(parts[1])
    return "/trunk"


def parse_changed_paths(logentry):
    paths_node = logentry.find("paths")
    changed_paths = []
    branch_events = []

    if paths_node is None:
        return changed_paths, branch_events

    for path_node in paths_node.findall("path"):
        path = normalize_path(path_node.text or "")
        action = path_node.get("action") or ""
        copyfrom_path = normalize_path(path_node.get("copyfrom-path") or "")
        copyfrom_rev = parse_int(path_node.get("copyfrom-rev"))

        changed_path = {
            "action": action,
            "path": path,
        }
        if copyfrom_path:
            changed_path["copyfrom_path"] = copyfrom_path
        if copyfrom_rev is not None:
            changed_path["copyfrom_rev"] = copyfrom_rev

        changed_paths.append(changed_path)

        root_path, kind = lineage_root(path)
        is_lineage_root = root_path is not None and root_path == path
        if action == "A" and copyfrom_path and copyfrom_rev is not None and is_lineage_root:
            branch_events.append(
                {
                    "path": root_path,
                    "kind": kind,
                    "origin_rev": parse_int(logentry.get("revision")),
                    "copyfrom_path": copyfrom_path,
                    "copyfrom_rev": copyfrom_rev,
                }
            )

    return changed_paths, branch_events


def clean_message(message):
    if not message:
        return ""

    noise_patterns = [
        r"^\s*Merged revisions?\s+.+",
        r"^\s*Merged revision\s+.+",
        r"^\s*Merge from\s+.+",
        r"^\s*Auto(?:matic)? merge\s+.+",
        r"^\s*This commit was manufactured by cvs2svn.+",
        r"^\s*-{8,}\s*$",
    ]

    kept_lines = []
    for raw_line in message.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw_line.strip()
        if not line:
            continue
        if any(re.match(pattern, line, flags=re.IGNORECASE) for pattern in noise_patterns):
            continue
        kept_lines.append(line)

    cleaned = " ".join(kept_lines)
    return re.sub(r"\s+", " ", cleaned).strip()


def extract_ticket_id(message, ticket_regex):
    if not message or not ticket_regex:
        return ""

    matches = re.findall(ticket_regex, message)
    ticket_ids = []
    for match in matches:
        if isinstance(match, tuple):
            match = next((item for item in match if item), "")
        if match and match not in ticket_ids:
            ticket_ids.append(match)

    return ";".join(ticket_ids)


def parse_log_entries(xml_text, ticket_regex):
    root = ET.fromstring(xml_text)
    entries = []
    branch_events = []

    for logentry in root.findall("logentry"):
        revision = parse_int(logentry.get("revision"))
        if revision is None:
            continue

        author = text_or_empty(logentry.find("author"))
        date = text_or_empty(logentry.find("date"))
        raw_message = text_or_empty(logentry.find("msg"))
        message = clean_message(raw_message)
        changed_paths, entry_branch_events = parse_changed_paths(logentry)

        entries.append(
            {
                "revision": revision,
                "author": author,
                "date": date,
                "ticket_id": extract_ticket_id(message, ticket_regex),
                "message": message,
                "changed_paths": json.dumps(changed_paths, ensure_ascii=False),
            }
        )
        branch_events.extend(entry_branch_events)

    entries.sort(key=lambda item: item["revision"])
    branch_events.sort(key=lambda item: item["origin_rev"] or 0)
    return entries, branch_events


def text_or_empty(node):
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def shard_name(date_text):
    year = "unknown"
    month = 1

    if date_text:
        try:
            normalized = date_text.replace("Z", "+00:00")
            dt = datetime.fromisoformat(normalized)
            year = str(dt.year)
            month = dt.month
        except ValueError:
            match = re.match(r"^(\d{4})-(\d{2})-", date_text)
            if match:
                year = match.group(1)
                month = int(match.group(2))

    half = "H1" if month <= 6 else "H2"
    return "commits_{0}_{1}.csv".format(year, half)


def ensure_output_dir(output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)


def highest_existing_revision(output_dir):
    highest = 0
    if not os.path.isdir(output_dir):
        return highest

    for filename in os.listdir(output_dir):
        if not re.match(r"^commits_\d{4}_H[12]\.csv$", filename):
            continue

        csv_path = os.path.join(output_dir, filename)
        with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                revision = parse_int(row.get("revision"))
                if revision is not None:
                    highest = max(highest, revision)

    return highest


def write_commit_shards(output_dir, entries):
    by_shard = {}
    for entry in entries:
        by_shard.setdefault(shard_name(entry["date"]), []).append(entry)

    for filename, shard_entries in sorted(by_shard.items()):
        csv_path = os.path.join(output_dir, filename)
        file_exists = os.path.exists(csv_path) and os.path.getsize(csv_path) > 0

        with open(csv_path, "a", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
            if not file_exists:
                writer.writeheader()
            writer.writerows(shard_entries)


def load_topology(output_dir):
    topology_path = os.path.join(output_dir, "branch_topology.json")
    if not os.path.exists(topology_path):
        return {}

    with open(topology_path, "r", encoding="utf-8") as f:
        return json.load(f)


def ensure_topology_node(topology, path):
    if path not in topology:
        topology[path] = {"children": []}
    elif "children" not in topology[path]:
        topology[path]["children"] = []
    return topology[path]


def update_topology(topology, branch_events):
    for event in branch_events:
        path = event["path"]
        parent = event["copyfrom_path"]
        parent_rev = event["copyfrom_rev"]

        parent_node = ensure_topology_node(topology, parent)
        if path not in parent_node["children"]:
            parent_node["children"].append(path)

        node = ensure_topology_node(topology, path)
        node.update(
            {
                "kind": event["kind"],
                "origin_rev": event["origin_rev"],
                "parent": parent,
                "parent_rev": parent_rev,
                "copyfrom_path": parent,
                "copyfrom_rev": parent_rev,
            }
        )

    for node in topology.values():
        if "children" in node:
            node["children"] = sorted(set(node["children"]))


def ensure_topology_roots(topology, roots):
    for path in sorted(normalize_trunk_roots(roots)):
        node = ensure_topology_node(topology, path)
        node.setdefault("kind", "trunk")

    if "/trunk" in topology and any(path.startswith("/trunk/") for path in roots):
        if not topology["/trunk"].get("children") and len(topology["/trunk"]) <= 2:
            del topology["/trunk"]


def normalize_trunk_roots(roots):
    normalized = set(roots)
    if any(path.startswith("/trunk/") for path in normalized):
        normalized.discard("/trunk")
    return normalized


def infer_trunk_roots_from_entries(entries):
    roots = set()
    for entry in entries:
        try:
            changed_paths = json.loads(entry.get("changed_paths") or "[]")
        except json.JSONDecodeError:
            changed_paths = []
        for changed_path in changed_paths:
            root = trunk_root(changed_path.get("path") or "")
            if root:
                roots.add(root)
    return roots


def infer_trunk_roots_from_existing_commits(output_dir):
    roots = set()
    if not os.path.isdir(output_dir):
        return roots

    for filename in os.listdir(output_dir):
        if not re.match(r"^commits_\d{4}_H[12]\.csv$", filename):
            continue

        csv_path = os.path.join(output_dir, filename)
        with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    changed_paths = json.loads(row.get("changed_paths") or "[]")
                except json.JSONDecodeError:
                    changed_paths = []
                for changed_path in changed_paths:
                    root = trunk_root(changed_path.get("path") or "")
                    if root:
                        roots.add(root)
    return roots


def write_topology(output_dir, topology):
    topology_path = os.path.join(output_dir, "branch_topology.json")
    temp_path = topology_path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(topology, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(temp_path, topology_path)


def print_usage():
    print("Usage: python svn_to_ai_loader.py [config.json]")
    print("Default config path: config.json")


def main(argv):
    if len(argv) > 1 and argv[1] in ("-h", "--help"):
        print_usage()
        return 0

    config_path = argv[1] if len(argv) > 1 else "config.json"
    config = load_config(config_path)
    output_dir = config["output_dir"]
    ensure_output_dir(output_dir)

    last_revision = highest_existing_revision(output_dir)
    start_revision = max(last_revision + 1, int(config.get("start_revision", 1)))
    head_revision = fetch_head_revision(config)

    if start_revision > head_revision:
        topology = load_topology(output_dir)
        ensure_topology_roots(topology, infer_trunk_roots_from_existing_commits(output_dir))
        write_topology(output_dir, topology)
        print(
            "已是最新狀態。last_revision={0}, HEAD={1}".format(
                last_revision,
                head_revision,
            )
        )
        return 0

    print("開始抓取 SVN log：r{0}:HEAD".format(start_revision))
    xml_text = fetch_log_xml(config, start_revision)
    entries, branch_events = parse_log_entries(xml_text, config.get("ticket_regex", ""))

    topology = load_topology(output_dir)
    update_topology(topology, branch_events)
    ensure_topology_roots(
        topology,
        infer_trunk_roots_from_existing_commits(output_dir)
        | infer_trunk_roots_from_entries(entries),
    )

    write_commit_shards(output_dir, entries)
    write_topology(output_dir, topology)

    print(
        "完成：新增 {0} 筆 commit，更新 {1} 筆分支/標籤事件。輸出目錄：{2}".format(
            len(entries),
            len(branch_events),
            output_dir,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
