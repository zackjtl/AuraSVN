import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
# 本 repo 的後端在 scripts/ 下；舊版 SVNBranchViewer 則在專案根。輸出與 .runtime_configs 一律以「專案根」為準。
if os.path.basename(_THIS_DIR).lower() == "scripts":
    PROJECT_ROOT = os.path.normpath(os.path.join(_THIS_DIR, ".."))
else:
    PROJECT_ROOT = _THIS_DIR
_SCRIPTS_LOADER = os.path.join(PROJECT_ROOT, "scripts", "svn_to_ai_loader.py")
SVN_TO_AI_LOADER = (
    _SCRIPTS_LOADER
    if os.path.isfile(_SCRIPTS_LOADER)
    else os.path.join(PROJECT_ROOT, "svn_to_ai_loader.py")
)
DEFAULT_OUTPUT_ROOT = os.path.join(PROJECT_ROOT, "svn_ai_output")
DEFAULT_REPOSITORIES = {
    "ET1288_AP": "https://svn1.embestor.local/svn/ET1288_AP",
    "ET1289_AP": "https://svn1.embestor.local/svn/ET1289_AP",
    "ET1290_AP": "https://svn1.embestor.local/svn/ET1290_AP",
}
SVN_TRUST_ARG = (
    "--trust-server-cert-failures="
    "unknown-ca,cn-mismatch,expired,not-yet-valid,other"
)

csv.field_size_limit(1024 * 1024 * 128)


TOOL_DEFINITIONS = [
    {
        "name": "list_branches",
        "description": "列出指定 repo 已解析出的 branch topology 節點。",
        "side_effect": False,
        "args": {"repo": "ET1289_AP"},
    },
    {
        "name": "get_project_summary",
        "description": "取得 repo commit 數、branch 數、最新 revisions 等精簡摘要。",
        "side_effect": False,
        "args": {"repo": "ET1289_AP"},
    },
    {
        "name": "get_branch_commits",
        "description": "取得指定 branch path 相關 commits，避免 AI 直接掃描所有 CSV。",
        "side_effect": False,
        "args": {"repo": "ET1289_AP", "branch_path": "/branches/BR263", "limit": 80},
    },
    {
        "name": "svn_info",
        "description": "呼叫受控 svn info --xml，只允許預先定義的 repo。",
        "side_effect": False,
        "args": {"repo": "ET1289_AP"},
    },
    {
        "name": "svn_log_revision",
        "description": "呼叫受控 svn log -v -r REV，只允許預先定義的 repo 與單一 revision。",
        "side_effect": False,
        "args": {"repo": "ET1289_AP", "revision": 316},
    },
    {
        "name": "update_repo",
        "description": "執行 svn_to_ai_loader.py 增量更新指定 repo。",
        "side_effect": True,
        "args": {"repo": "ET1289_AP"},
    },
]


def main():
    parser = argparse.ArgumentParser(description="SVN Branch Viewer local backend")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), ApiHandler)
    print(f"SVN Branch Viewer backend listening on http://{args.host}:{args.port}")
    server.serve_forever()


class ApiHandler(BaseHTTPRequestHandler):
    server_version = "SVNBranchViewerBackend/0.1"

    def do_OPTIONS(self):
        self._send_empty(204)

    def do_GET(self):
        if self.path == "/api/health":
            self._send_json(
                {
                    "ok": True,
                    "project_root": PROJECT_ROOT,
                    "ollama_api_key_loaded": bool(get_ollama_api_key()),
                }
            )
            return
        if self.path == "/api/tools":
            self._send_json({"tools": TOOL_DEFINITIONS})
            return
        self._send_json({"error": "not found"}, status=404)

    def do_POST(self):
        try:
            payload = self._read_json()
            if self.path == "/api/notes/read":
                self._send_json(read_branch_note(payload))
                return
            if self.path == "/api/notes/write":
                self._send_json(write_branch_note(payload))
                return
            if self.path == "/api/reports/project":
                self._send_json(generate_project_report(payload))
                return
            if self.path == "/api/reports/project_stream":
                self._send_project_report_stream(payload)
                return
            if self.path == "/api/reports/history":
                self._send_json(read_project_report_history_for_repo(payload))
                return
            if self.path == "/api/revisions/diff":
                self._send_json(load_revision_diff(payload))
                return
            if self.path == "/api/tools/run":
                self._send_json(run_tool(payload))
                return
            if self.path == "/api/ollama/test":
                self._send_json(test_ollama_settings(payload))
                return
            self._send_json({"error": "not found"}, status=404)
        except Exception as exc:
            self._send_json({"error": str(exc)}, status=500)

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def _send_empty(self, status):
        self.send_response(status)
        self._send_headers()
        self.end_headers()

    def _send_json(self, payload, status=200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._send_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_project_report_stream(self, payload):
        self.send_response(200)
        self._send_headers()
        self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        def emit(message, level="info", **extra):
            event = {
                "type": "log",
                "level": level,
                "time": datetime.now().isoformat(timespec="seconds"),
                "message": message,
            }
            event.update(extra)
            self._write_ndjson(event)

        try:
            emit("開始產生專案級報告")
            result = generate_project_report(payload, progress=emit)
            self._write_ndjson({"type": "result", **result})
            emit("專案級報告完成")
        except Exception as exc:
            self._write_ndjson(
                {
                    "type": "error",
                    "level": "error",
                    "time": datetime.now().isoformat(timespec="seconds"),
                    "message": str(exc),
                }
            )

    def _write_ndjson(self, payload):
        data = (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")
        self.wfile.write(data)
        self.wfile.flush()

    def _send_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def run_tool(payload):
    tool = require_text(payload, "tool")
    args = payload.get("args") or {}
    if not isinstance(args, dict):
        raise ValueError("args must be an object")

    if tool == "list_branches":
        repo = validate_repo(args.get("repo"))
        topology = read_topology(repo, args.get("output_dir"))
        return {"repo": repo, "branches": sorted(topology.keys())}
    if tool == "get_project_summary":
        repo = validate_repo(args.get("repo"))
        return get_project_summary(repo, args.get("output_dir"))
    if tool == "get_branch_commits":
        repo = validate_repo(args.get("repo"))
        branch_path = require_text(args, "branch_path")
        limit = int(args.get("limit") or 80)
        commits = read_commits(repo, args.get("output_dir"))
        return {
            "repo": repo,
            "branch_path": branch_path,
            "commits": filter_branch_commits(commits, branch_path)[:limit],
        }
    if tool == "svn_info":
        repo = validate_repo(args.get("repo"))
        return {"repo": repo, "stdout": run_svn(["info", "--xml", repo_url(repo)])}
    if tool == "svn_log_revision":
        repo = validate_repo(args.get("repo"))
        revision = int(args.get("revision"))
        return {
            "repo": repo,
            "revision": revision,
            "stdout": run_svn(["log", "-v", "-r", str(revision), repo_url(repo)]),
        }
    if tool == "update_repo":
        repo = validate_repo(args.get("repo"))
        return update_repo(repo, args)

    raise ValueError(f"unsupported tool: {tool}")


def read_branch_note(payload):
    notes_root = require_text(payload, "notes_root")
    repo = validate_repo(payload.get("repo"))
    branch_path = require_text(payload, "branch_path")
    note_file = branch_note_file(notes_root, repo, branch_path)
    if not os.path.exists(note_file):
        return {
            "repo": repo,
            "branch_path": branch_path,
            "note_file": note_file,
            "content": default_branch_note(repo, branch_path),
            "exists": False,
            "updated_at": "",
        }

    stat = os.stat(note_file)
    return {
        "repo": repo,
        "branch_path": branch_path,
        "note_file": note_file,
        "content": read_text(note_file),
        "exists": True,
        "updated_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
    }


def write_branch_note(payload):
    notes_root = require_text(payload, "notes_root")
    repo = validate_repo(payload.get("repo"))
    branch_path = require_text(payload, "branch_path")
    content = payload.get("content")
    if not isinstance(content, str):
        raise ValueError("content must be a string")

    note_file = branch_note_file(notes_root, repo, branch_path)
    ensure_dir(os.path.dirname(note_file))
    write_text(note_file, content)
    upsert_note_index(notes_root, repo, branch_path, note_file)
    stat = os.stat(note_file)
    return {
        "repo": repo,
        "branch_path": branch_path,
        "note_file": note_file,
        "content": content,
        "exists": True,
        "updated_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
    }


def load_revision_diff(payload):
    repo = validate_repo(payload.get("repo"))
    revision = int(payload.get("revision") or 0)
    if revision <= 0:
        raise ValueError("revision must be a positive integer")
    output_dir = resolve_output_dir(repo, payload.get("output_dir"))
    refresh = bool(payload.get("refresh"))
    changed_path = str(payload.get("path") or "").strip()

    cache_file = revision_diff_cache_file(output_dir, revision, changed_path)
    if os.path.exists(cache_file) and not refresh:
        return {
            "repo": repo,
            "revision": revision,
            "path": changed_path,
            "diff": read_text(cache_file),
            "cache_file": cache_file,
            "cached": True,
        }

    target = revision_diff_target(repo, changed_path)
    diff = run_svn(["diff", "-c", str(revision), target])
    ensure_dir(os.path.dirname(cache_file))
    write_text(cache_file, diff)
    return {
        "repo": repo,
        "revision": revision,
        "path": changed_path,
        "diff": diff,
        "cache_file": cache_file,
        "cached": False,
    }


def revision_diff_target(repo, changed_path):
    base = repo_url(repo).rstrip("/")
    if not changed_path:
        return base
    return f"{base}/{changed_path.lstrip('/')}"


def revision_diff_cache_file(output_dir, revision, changed_path=""):
    if not changed_path:
        return os.path.join(output_dir, "revision_cache", f"r{revision}.diff")
    digest = hashlib.sha1(changed_path.encode("utf-8")).hexdigest()[:12]
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", changed_path.strip("/"))[-90:]
    if not name:
        name = "path"
    return os.path.join(
        output_dir,
        "revision_cache",
        f"r{revision}",
        f"{digest}_{name}.diff",
    )


def generate_project_report(payload, progress=None):
    def emit(message, level="info", **extra):
        if progress:
            progress(message, level=level, **extra)

    repo = validate_repo(payload.get("repo"))
    notes_root = require_text(payload, "notes_root")
    ollama_base_url = (payload.get("ollama_base_url") or "http://localhost:11434").rstrip("/")
    model = payload.get("model") or "qwen3-coder-next"
    output_dir = payload.get("output_dir")
    user_prompt = str(payload.get("user_prompt") or "").strip()
    report_title = str(payload.get("report_title") or "").strip()
    if not report_title:
        report_title = default_project_report_title(repo, user_prompt)
    emit(f"報告標題：{report_title}")
    if user_prompt:
        emit(f"使用者分析要求：{user_prompt}")

    emit(f"讀取 {repo} 專案摘要")
    summary = get_project_summary(repo, output_dir)
    emit(
        "摘要完成",
        commit_count=summary["commit_count"],
        topology_node_count=summary["topology_node_count"],
        latest_revision=summary["latest_revision"],
    )
    emit("讀取分支拓樸")
    topology = read_topology(repo, output_dir)
    emit(f"分支拓樸完成，共 {len(topology)} 個節點")
    emit("讀取 commit CSV")
    commits = read_commits(repo, output_dir)
    recent_commits = commits[:80]
    emit(f"commit 讀取完成，共 {len(commits)} 筆，本次提供最近 {len(recent_commits)} 筆給 AI")
    prompt_related_commits = find_prompt_related_commits(commits, user_prompt, limit=120)
    if user_prompt:
        emit(f"依使用者 prompt 初步比對到 {len(prompt_related_commits)} 筆相關 commit")
    emit("讀取使用者建立的 branch Markdown 筆記")
    branch_notes = read_branch_notes_for_report(notes_root, repo, user_prompt=user_prompt)
    emit(f"branch 筆記讀取完成，共納入 {len(branch_notes)} 份筆記")
    emit("組合 AI prompt、筆記內容與筆記索引")
    prompt = build_project_report_prompt(
        repo,
        summary,
        topology,
        recent_commits,
        notes_root,
        user_prompt=user_prompt,
        prompt_related_commits=prompt_related_commits,
        branch_notes=branch_notes,
    )
    emit(f"送出 LLM 請求，model={model}，等待模型回應")
    api_key_for_chat = _ollama_api_key_from_client_payload(payload)
    report = call_ollama_chat(
        ollama_base_url, model, prompt, api_key_for_request=api_key_for_chat
    )
    emit(f"LLM 已回應，報告長度 {len(report)} 字元")
    emit("儲存報告 Markdown 與 history index")
    report_entry = save_project_report(
        notes_root,
        repo,
        report,
        title=report_title,
        prompt=user_prompt,
        model=model,
    )
    report_file = report_entry["report_file"]
    emit(f"報告已儲存：{report_file}")
    return {
        "id": report_entry["id"],
        "repo": repo,
        "model": model,
        "title": report_entry["title"],
        "report": report,
        "report_file": report_file,
        "user_prompt": user_prompt,
        "created_at": report_entry["created_at"],
    }


def build_project_report_prompt(
    repo,
    summary,
    topology,
    recent_commits,
    notes_root,
    user_prompt="",
    prompt_related_commits=None,
    branch_notes=None,
):
    compact_branches = []
    for path, node in sorted(topology.items()):
        compact_branches.append(
            {
                "path": path,
                "origin_rev": node.get("origin_rev"),
                "parent": node.get("parent"),
                "parent_rev": node.get("parent_rev"),
                "children": node.get("children", []),
            }
        )

    prompt_related_commits = prompt_related_commits or []
    branch_notes = branch_notes or []
    repo_svn_url = repo_url(repo)
    context = {
        "repo": repo,
        "repo_svn_url": repo_svn_url,
        "user_prompt": user_prompt,
        "summary": summary,
        "branches": compact_branches[:120],
        "recent_commits": [compact_commit(c) for c in recent_commits],
        "prompt_related_commits": [
            compact_commit(c, include_paths=True) for c in prompt_related_commits
        ],
        "notes_index": read_note_index(notes_root),
        "branch_notes": branch_notes,
    }
    user_request = (
        f"\n使用者額外分析要求：\n{user_prompt}\n"
        "請優先回答這個要求；如果要求是在找特定修改，請列出最相關的 revision、原因、相關路徑與可信度。\n"
        if user_prompt
        else ""
    )
    return (
        "你是內網 SVN 專案分析助理。請根據下列 JSON 產生繁體中文 Markdown 專案級報告。\n"
        "要求：\n"
        "0. 報告開頭請用一小段列出 JSON 中的 `repo`（倉儲識別名）與 `repo_svn_url`（SVN 根 URL，若為 null 則註明未設定）。\n"
        "1. 摘要 repo 目前分支狀態與近期開發重點。\n"
        "2. 列出重要分支、長期風險與建議追蹤項目。\n"
        "3. 引用 revision 時必須使用資料中存在的 revision。\n"
        "4. 不要宣稱你看過原始碼，只能根據 commit/topology/notes 判斷。\n\n"
        "5. branch_notes 是使用者手寫 Markdown 筆記，可信度高於單純由 commit message 推測；"
        "請在分析分支目的、風險、狀態時優先參考它，並明確標示哪些結論來自筆記。\n\n"
        f"{user_request}"
        f"資料：\n{json.dumps(context, ensure_ascii=False, indent=2)}"
    )


def compact_commit(commit, include_paths=False):
    item = {
        "revision": commit["revision"],
        "author": commit["author"],
        "date": commit["date"],
        "ticket_id": commit["ticket_id"],
        "message": commit["message"],
        "changed_path_count": len(commit["changed_paths"]),
    }
    if include_paths:
        item["changed_paths"] = [
            {
                "action": path.get("action"),
                "path": path.get("path"),
                "copyfrom_path": path.get("copyfrom_path"),
                "copyfrom_rev": path.get("copyfrom_rev"),
            }
            for path in commit["changed_paths"][:30]
        ]
    return item


def find_prompt_related_commits(commits, user_prompt, limit=120):
    terms = extract_prompt_terms(user_prompt)
    if not terms:
        return []
    scored = []
    for commit in commits:
        haystack_parts = [
            str(commit.get("revision") or ""),
            commit.get("author") or "",
            commit.get("ticket_id") or "",
            commit.get("message") or "",
        ]
        for path in commit.get("changed_paths") or []:
            haystack_parts.append(str(path.get("path") or ""))
            haystack_parts.append(str(path.get("copyfrom_path") or ""))
        haystack = "\n".join(haystack_parts).lower()
        score = sum(1 for term in terms if term in haystack)
        if score > 0:
            scored.append((score, commit["revision"], commit))
    scored.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [item[2] for item in scored[:limit]]


def extract_prompt_terms(user_prompt):
    text = (user_prompt or "").strip().lower()
    if not text:
        return []
    raw_terms = []
    for pattern in (
        r"(?:有關於|有關|關於)([^，。,.；;\s]{2,})(?:的|修改|commit|revision|節點|$)",
        r"找(?:出)?([^，。,.；;\s]{2,})(?:的|修改|commit|revision|節點|$)",
    ):
        raw_terms.extend(re.findall(pattern, text))
    raw_terms.extend(re.findall(r"[a-z0-9_#.-]+|[\u4e00-\u9fff]{2,}", text))
    stop_terms = {
        "幫我",
        "找出",
        "有關",
        "關於",
        "修改",
        "commit",
        "revision",
        "節點",
        "分析",
        "報告",
        "哪些",
        "相關",
    }
    terms = []
    for term in raw_terms:
        term = re.sub(r"^(幫我)?(找出|找)?(有關於|有關|關於)?", "", term)
        term = re.sub(r"(的|修改|相關|commit|revision|節點|分析|報告)+$", "", term)
        if term in stop_terms or len(term) < 2:
            continue
        if term not in terms:
            terms.append(term)
    return terms[:12]


def _ollama_api_key_from_client_payload(payload):
    """若 payload 含 ollama_api_key，使用客戶端值（可為空字串）；否則回傳 None 表示改讀後端 app_settings。"""
    if "ollama_api_key" not in payload:
        return None
    raw = payload.get("ollama_api_key")
    if isinstance(raw, str):
        return raw.strip()
    return ""


def _ollama_headers_for_key(api_key):
    headers = {"Content-Type": "application/json"}
    if not isinstance(api_key, str):
        return headers
    key = api_key.strip()
    if not key:
        return headers
    header_name = os.environ.get("OLLAMA_API_KEY_HEADER", "Authorization").strip()
    if header_name.lower() == "authorization":
        headers[header_name] = f"Bearer {key}"
    else:
        headers[header_name] = key
    return headers


def test_ollama_settings(payload):
    base_url = require_text(payload, "ollama_base_url")
    model = require_text(payload, "model")
    raw_key = payload.get("api_key")
    api_key = raw_key.strip() if isinstance(raw_key, str) else ""

    chat_url = ollama_api_url(base_url, "chat")
    body = {
        "model": model,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": "You answer briefly in one short phrase.",
            },
            {"role": "user", "content": "Reply with exactly: pong"},
        ],
        "options": {"num_predict": 32},
    }
    request = urllib.request.Request(
        chat_url,
        data=json.dumps(body).encode("utf-8"),
        headers=_ollama_headers_for_key(api_key),
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            decoded = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        detail = body.strip() or exc.reason
        raise RuntimeError(f"LLM request failed: HTTP {exc.code} {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"LLM request failed: {exc}") from exc

    content = decoded.get("message", {}).get("content", "").strip()
    preview = content[:200] if content else "(empty reply)"
    return {
        "ok": True,
        "reply_preview": preview,
        "model": model,
        "ollama_chat_url": chat_url,
    }


def call_ollama_chat(base_url, model, prompt, *, api_key_for_request=None):
    """api_key_for_request: None 時從後端 app_settings 讀取；否則用該字串（可為空）組 Authorization。"""
    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": "你是嚴謹的軟體版本演進分析助理。"},
            {"role": "user", "content": prompt},
        ],
    }
    if api_key_for_request is None:
        key = get_ollama_api_key()
    else:
        key = api_key_for_request
    headers = _ollama_headers_for_key(key)

    request = urllib.request.Request(
        ollama_api_url(base_url, "chat"),
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            decoded = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        detail = body.strip() or exc.reason
        raise RuntimeError(f"LLM request failed: HTTP {exc.code} {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"LLM request failed: {exc}") from exc
    return decoded.get("message", {}).get("content", "").strip()


def ollama_api_url(base_url, endpoint):
    base = base_url.rstrip("/")
    endpoint = endpoint.strip("/")
    if base.endswith("/api"):
        return f"{base}/{endpoint}"
    return f"{base}/api/{endpoint}"


def get_project_summary(repo, output_dir=None):
    topology = read_topology(repo, output_dir)
    commits = read_commits(repo, output_dir)
    return {
        "repo": repo,
        "commit_count": len(commits),
        "topology_node_count": len(topology),
        "latest_revision": commits[0]["revision"] if commits else None,
        "latest_date": commits[0]["date"] if commits else "",
        "latest_author": commits[0]["author"] if commits else "",
        "branch_count": len([p for p in topology if "/branches/" in p]),
        "tag_count": len([p for p in topology if "/tags/" in p]),
    }


def read_topology(repo, output_dir=None):
    topology_path = os.path.join(resolve_output_dir(repo, output_dir), "branch_topology.json")
    if not os.path.exists(topology_path):
        return {}
    with open(topology_path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def read_commits(repo, output_dir=None):
    root = resolve_output_dir(repo, output_dir)
    if not os.path.isdir(root):
        return []
    rows = []
    for filename in sorted(os.listdir(root)):
        if not re.match(r"^commits_\d{4}_H[12]\.csv$", filename):
            continue
        with open(os.path.join(root, filename), "r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                try:
                    changed_paths = json.loads(row.get("changed_paths") or "[]")
                except json.JSONDecodeError:
                    changed_paths = []
                rows.append(
                    {
                        "revision": int(row.get("revision") or 0),
                        "author": row.get("author") or "",
                        "date": row.get("date") or "",
                        "ticket_id": row.get("ticket_id") or "",
                        "message": row.get("message") or "",
                        "changed_paths": changed_paths,
                    }
                )
    rows.sort(key=lambda item: item["revision"], reverse=True)
    return rows


def filter_branch_commits(commits, branch_path):
    result = []
    for commit in commits:
        for path in commit["changed_paths"]:
            changed_path = str(path.get("path") or "")
            copyfrom_path = str(path.get("copyfrom_path") or "")
            if branch_path in changed_path or branch_path in copyfrom_path:
                result.append(commit)
                break
    return result


def update_repo(repo, args):
    config_dir = os.path.join(PROJECT_ROOT, ".runtime_configs")
    ensure_dir(config_dir)
    config_path = os.path.join(config_dir, f"backend_{repo}.json")
    config = {
        "svn_url": repo_url(repo),
        "username": args.get("username") or "",
        "password": args.get("password") or "",
        "output_dir": resolve_output_dir(repo, args.get("output_dir")),
        "svn_executable": default_svn_executable(),
        "extra_svn_args": default_svn_args(),
        "ticket_regex": r"([A-Z][A-Z0-9]+-\d+|[A-Z]{2,}\d{3,}|#\d+)",
        "start_revision": 1,
    }
    write_text(config_path, json.dumps(config, ensure_ascii=False, indent=2))
    completed = subprocess.run(
        [sys.executable, SVN_TO_AI_LOADER, config_path],
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=False,
        env={**os.environ, "PYTHONIOENCODING": "utf-8", "PYTHONUTF8": "1"},
    )
    return {
        "repo": repo,
        "exit_code": completed.returncode,
        "stdout": decode_process_output(completed.stdout),
        "stderr": decode_process_output(completed.stderr),
    }


def run_svn(args):
    completed = subprocess.run(
        [default_svn_executable(), *default_svn_args(), *args],
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=False,
    )
    stdout = decode_process_output(completed.stdout)
    stderr = decode_process_output(completed.stderr)
    if completed.returncode != 0:
        raise RuntimeError(stderr or stdout)
    return stdout


def default_svn_executable():
    settings_command = read_app_settings().get("svn_command")
    if isinstance(settings_command, str) and settings_command.strip():
        return settings_command.strip()
    tortoise_svn = r"C:\Program Files\TortoiseSVN\bin\svn.exe"
    if os.name == "nt" and os.path.exists(tortoise_svn):
        return tortoise_svn
    return "svn"


def default_svn_args():
    settings_args = read_app_settings().get("svn_command_parameters")
    if isinstance(settings_args, str) and settings_args.strip():
        return split_command_line(settings_args)
    return ["--non-interactive", SVN_TRUST_ARG]


def read_app_settings():
    path = os.path.join(PROJECT_ROOT, ".runtime_configs", "app_settings.json")
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            decoded = json.load(handle)
        return decoded if isinstance(decoded, dict) else {}
    except Exception:
        return {}


def split_command_line(command):
    parts = []
    current = []
    in_single = False
    in_double = False
    for char in command:
        if char == "'" and not in_double:
            in_single = not in_single
            continue
        if char == '"' and not in_single:
            in_double = not in_double
            continue
        if char.isspace() and not in_single and not in_double:
            if current:
                parts.append("".join(current))
                current = []
            continue
        current.append(char)
    if current:
        parts.append("".join(current))
    return parts


def save_project_report(notes_root, repo, report, title="", prompt="", model=""):
    report_dir = project_report_dir(notes_root, repo)
    ensure_dir(report_dir)
    now = datetime.now()
    report_id = f"{repo}_{now.strftime('%Y%m%d_%H%M%S_%f')}"
    filename = f"{report_id}.md"
    path = os.path.join(report_dir, filename)
    write_text(path, report)
    entry = {
        "id": report_id,
        "repo": repo,
        "model": model,
        "title": title or default_project_report_title(repo, prompt),
        "prompt": prompt,
        "report": report,
        "report_file": path,
        "created_at": now.isoformat(),
    }
    append_project_report_history(notes_root, repo, entry)
    return entry


def default_project_report_title(repo, prompt):
    prompt = (prompt or "").strip()
    if prompt:
        compact = re.sub(r"\s+", " ", prompt)
        if len(compact) > 42:
            compact = compact[:42].rstrip() + "..."
        return f"{repo} - {compact}"
    return f"{repo} 專案級報告"


def read_project_report_history_for_repo(payload):
    notes_root = require_text(payload, "notes_root")
    repo = validate_repo(payload.get("repo"))
    index = read_project_report_history(notes_root, repo)
    return {"repo": repo, "reports": index.get("reports") or []}


def append_project_report_history(notes_root, repo, entry):
    ensure_dir(project_report_dir(notes_root, repo))
    path = project_report_history_index_path(notes_root, repo)
    index = read_project_report_history(notes_root, repo)
    reports = list(index.get("reports") or [])
    reports.insert(0, entry)
    index["version"] = 1
    index["repo"] = repo
    index["reports"] = reports
    write_text(path, json.dumps(index, ensure_ascii=False, indent=2))


def read_project_report_history(notes_root, repo):
    reports = []
    seen = set()
    path = project_report_history_index_path(notes_root, repo)
    if not os.path.exists(path):
        data = {}
    else:
        data = read_json_file(path)
    for entry in data.get("reports") or []:
        normalized = normalize_project_report_entry(entry, repo)
        if not normalized:
            continue
        key = normalized.get("id") or normalized.get("report_file")
        if key not in seen:
            seen.add(key)
            reports.append(normalized)

    # Compatibility with reports created before per-project storage.
    legacy = read_json_file(legacy_project_report_history_index_path(notes_root))
    for entry in legacy.get("reports") or []:
        normalized = normalize_project_report_entry(entry, repo)
        if not normalized:
            continue
        key = normalized.get("id") or normalized.get("report_file")
        if key not in seen:
            seen.add(key)
            reports.append(normalized)

    reports.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return {"version": 1, "repo": repo, "reports": reports}


def project_report_dir(notes_root, repo):
    return os.path.join(notes_root, "reports", sanitize_path_segment(repo))


def project_report_history_index_path(notes_root, repo):
    return os.path.join(project_report_dir(notes_root, repo), "project_reports_index.json")


def legacy_project_report_history_index_path(notes_root):
    return os.path.join(notes_root, "reports", "project_reports_index.json")


def normalize_project_report_entry(entry, repo):
    if not isinstance(entry, dict) or entry.get("repo") != repo:
        return None
    normalized = {
        "id": str(entry.get("id") or ""),
        "repo": repo,
        "model": str(entry.get("model") or ""),
        "title": str(entry.get("title") or default_project_report_title(repo, "")),
        "prompt": str(entry.get("prompt") or ""),
        "report": str(entry.get("report") or ""),
        "report_file": str(entry.get("report_file") or ""),
        "created_at": str(entry.get("created_at") or ""),
    }
    if not normalized["report"] and normalized["report_file"]:
        try:
            normalized["report"] = read_text(normalized["report_file"])
        except Exception:
            normalized["report"] = ""
    return normalized


def read_json_file(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def read_note_index(notes_root):
    path = os.path.join(notes_root, "branch_notes_index.json")
    if not os.path.exists(path):
        return {"version": 1, "links": []}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {"version": 1, "links": []}


def read_branch_notes_for_report(
    notes_root,
    repo,
    user_prompt="",
    limit=40,
    max_chars_per_note=3000,
    max_total_chars=24000,
):
    index = read_note_index(notes_root)
    links = [
        item
        for item in index.get("links", [])
        if isinstance(item, dict) and item.get("repo") == repo
    ]
    terms = extract_prompt_terms(user_prompt)
    notes = []
    for link in links:
        note_file = note_file_from_index(notes_root, link.get("note_file"))
        if not note_file or not os.path.exists(note_file):
            continue
        try:
            content = read_text(note_file).strip()
        except OSError:
            continue
        if not meaningful_note_content(content):
            continue
        branch_path = str(link.get("branch_path") or "")
        score = score_branch_note(branch_path, content, terms)
        stat = os.stat(note_file)
        notes.append(
            {
                "repo": repo,
                "branch_path": branch_path,
                "branch_name": link.get("branch_name") or branch_name(branch_path),
                "note_file": link.get("note_file") or note_file,
                "updated_at": link.get("updated_at")
                or datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "mtime": stat.st_mtime,
                "score": score,
                "content": truncate_text(content, max_chars_per_note),
            }
        )

    if terms:
        notes.sort(key=lambda item: (item["score"], item["mtime"]), reverse=True)
    else:
        notes.sort(key=lambda item: item["mtime"], reverse=True)

    selected = []
    total_chars = 0
    for note in notes:
        content_length = len(note["content"])
        if selected and total_chars + content_length > max_total_chars:
            break
        note = dict(note)
        note.pop("mtime", None)
        selected.append(note)
        total_chars += content_length
        if len(selected) >= limit:
            break
    return selected


def note_file_from_index(notes_root, note_file):
    if not isinstance(note_file, str) or not note_file.strip():
        return ""
    note_file = note_file.strip()
    if os.path.isabs(note_file):
        return note_file
    return os.path.join(notes_root, note_file)


def meaningful_note_content(content):
    text = content.strip()
    if not text:
        return False
    # Default newly-created notes end with an empty "## Notes" section; skip them
    # so the model focuses on actual user-authored content.
    text_without_boilerplate = re.sub(r"^# .+?\n", "", text, count=1).strip()
    text_without_boilerplate = re.sub(
        r"^- Repo: .+?\n- Branch: `?.+?`?\n- Created: .+?\n",
        "",
        text_without_boilerplate,
        flags=re.MULTILINE,
    ).strip()
    text_without_boilerplate = re.sub(
        r"^## Notes\s*$",
        "",
        text_without_boilerplate,
        flags=re.MULTILINE,
    ).strip()
    return bool(text_without_boilerplate)


def score_branch_note(branch_path, content, terms):
    if not terms:
        return 0
    haystack = f"{branch_path}\n{content}".lower()
    return sum(1 for term in terms if term in haystack)


def truncate_text(text, max_chars):
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rstrip() + "\n\n...[truncated]"


def upsert_note_index(notes_root, repo, branch_path, note_file):
    ensure_dir(notes_root)
    index = read_note_index(notes_root)
    links = list(index.get("links") or [])
    links = [
        item
        for item in links
        if not (item.get("repo") == repo and item.get("branch_path") == branch_path)
    ]
    links.append(
        {
            "repo": repo,
            "branch_path": branch_path,
            "branch_name": branch_name(branch_path),
            "note_file": relative_note_path(repo, branch_path),
            "updated_at": datetime.now().isoformat(),
        }
    )
    links.sort(key=lambda item: (item.get("repo", ""), item.get("branch_path", "")))
    index["version"] = 1
    index["links"] = links
    write_text(
        os.path.join(notes_root, "branch_notes_index.json"),
        json.dumps(index, ensure_ascii=False, indent=2),
    )


def branch_note_file(notes_root, repo, branch_path):
    return os.path.join(notes_root, relative_note_path(repo, branch_path))


def relative_note_path(repo, branch_path):
    parts = [sanitize_path_segment(part) for part in branch_path.split("/") if part.strip()]
    if not parts:
        parts = ["root"]
    parts[-1] = f"{parts[-1]}.md"
    return os.path.join(repo, *parts)


def default_branch_note(repo, branch_path):
    return "\n".join(
        [
            f"# {branch_name(branch_path)}",
            "",
            f"- Repo: {repo}",
            f"- Branch: `{branch_path}`",
            f"- Created: {datetime.now().isoformat()}",
            "",
            "## Notes",
            "",
        ]
    )


def sanitize_path_segment(value):
    sanitized = re.sub(r'[<>:"\\|?*\x00-\x1F]', "_", value)
    sanitized = re.sub(r"\s+", " ", sanitized).strip()
    return sanitized or "_"


def branch_name(path):
    parts = [part for part in path.split("/") if part]
    return parts[-1] if parts else path


def resolve_output_dir(repo, output_dir=None):
    if output_dir:
        return output_dir
    return os.path.join(DEFAULT_OUTPUT_ROOT, repo)


def validate_repo(repo):
    repositories = configured_repositories()
    if repo not in repositories:
        raise ValueError(f"unsupported repo: {repo}")
    return repo


def repo_url(repo):
    return configured_repositories()[repo]


def configured_repositories():
    settings = read_app_settings()
    profiles = settings.get("repository_profiles")
    repositories = {}
    if isinstance(profiles, list):
        for profile in profiles:
            if not isinstance(profile, dict):
                continue
            title = str(profile.get("title") or "").strip()
            url = str(profile.get("svn_base_url") or "").strip()
            if title and url:
                repositories[title] = url
    return repositories or dict(DEFAULT_REPOSITORIES)


def require_text(payload, key):
    value = payload.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key} is required")
    return value.strip()


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def read_text(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def write_text(path, content):
    ensure_dir(os.path.dirname(path))
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(content)


def decode_process_output(data):
    for encoding in ("utf-8", "cp950", "big5"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", errors="replace")


def get_ollama_api_key():
    value = read_app_settings().get("ollama_api_key")
    return value.strip() if isinstance(value, str) else ""


if __name__ == "__main__":
    main()
