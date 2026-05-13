"""One-off: convert branch_map_view.dart from part file to library."""
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
path = root / "lib/branch_map_view.dart"
text = path.read_text(encoding="utf-8")
if text.startswith("part of "):
    text = "\n".join(text.splitlines()[1:])
header = """import 'dart:ui';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/branch_map_painter.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/branch_node.dart';
import 'package:aura_svn/models/commit_record.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/branch_paths.dart';
import 'package:aura_svn/widgets/markdown_styles.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphview/GraphView.dart' as graphview;

"""
repl = [
    ("_aura(", "aura("),
    ("_t(", "t("),
    ("_cyberBackground", "cyberBackground"),
    ("_stitchPrimaryFixed", "stitchPrimaryFixed"),
    ("_EmptyDataCard", "EmptyDataCard"),
    ("_BranchGraphModel", "BranchGraphModel"),
    ("_BranchMapNode", "BranchMapNode"),
    ("_MapNodeChip", "MapNodeChip"),
    ("_BranchMapTitle", "BranchMapTitle"),
    ("_BranchLogSheet", "BranchLogSheet"),
    ("_BranchCommitPreviewDialog", "BranchCommitPreviewDialog"),
    ("_loadBranchNote", "loadBranchNote"),
    ("_saveBranchNote", "saveBranchNote"),
    ("_auraMarkdownStyle", "auraMarkdownStyle"),
    ("_filterCommitsForBranch", "filterCommitsForBranch"),
    ("_isTrunkPath", "isTrunkPath"),
    ("_pickRootPath", "pickRootPath"),
    ("_branchName", "mapBranchName"),
]
for a, b in repl:
    text = text.replace(a, b)

lines = text.splitlines()
out = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.startswith("bool isTrunkPath(String path)"):
        i += 1
        while i < len(lines) and lines[i].strip() != "}":
            i += 1
        if i < len(lines):
            i += 1
        continue
    out.append(line)
    i += 1

text = "\n".join(out)
path.write_text(header + text + "\n", encoding="utf-8")
print("updated branch_map_view.dart")
