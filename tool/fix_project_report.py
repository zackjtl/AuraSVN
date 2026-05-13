"""Convert project_report_view.dart from part to library."""
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
path = root / "lib/project_report_view.dart"
lines = path.read_text(encoding="utf-8").splitlines()
# Drop BOM and part line
while lines and (lines[0].startswith("part of") or lines[0].strip() == ""):
    lines = lines[1:]
# Remove ProjectReportLogEntry class (first ~21 lines until blank after closing brace)
out = []
i = 0
if lines[0].startswith("class ProjectReportLogEntry"):
    depth = 0
    while i < len(lines):
        l = lines[i]
        if "{" in l:
            depth += l.count("{") - l.count("}")
        elif "}" in l:
            depth -= l.count("}")
        i += 1
        if i > 0 and lines[i - 1].startswith("class ProjectReportLogEntry") is False and depth <= 0 and "}" in l:
            break
    # simpler: skip until we've seen class closing for ProjectReportLogEntry
i = 0
skipping = False
brace = 0
for idx, line in enumerate(lines):
    if line.startswith("class ProjectReportLogEntry"):
        skipping = True
        brace = line.count("{") - line.count("}")
        continue
    if skipping:
        brace += line.count("{") - line.count("}")
        if brace <= 0:
            skipping = False
        continue
    out.append(line)

text = "\n".join(out)
header = """import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/project_report_log_entry.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/helpers.dart';
import 'package:aura_svn/widgets/markdown_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

"""
repl = [
    ("_t(", "t("),
    ("_aura(", "aura("),
    ("_parseDateTime", "parseDateTime"),
    ("_loadProjectReportHistory", "loadProjectReportHistory"),
    ("_generateProjectReportStream", "generateProjectReportStream"),
    ("_auraMarkdownStyle", "auraMarkdownStyle"),
    ("_ProjectReport", "_ProjectReport"),
]
# last line noop - keep _ProjectReport private widgets as underscore is ok in same file

for a, b in repl:
    if a == "_ProjectReport":
        continue
    text = text.replace(a, b)

path.write_text(header + text + "\n", encoding="utf-8")
print("project_report_view done")
