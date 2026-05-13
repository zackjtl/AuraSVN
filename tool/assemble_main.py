"""Assemble slim lib/main.dart from existing monolith."""
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
lines = (root / "lib/main.dart").read_text(encoding="utf-8").splitlines()
# Lines 283-1736 inclusive in 1-based -> indices 282:1736
body = "\n".join(lines[282:1736])
repl = [
    ("_defaultRepositories", "defaultRepositories"),
    ("_findProjectRoot", "findProjectRoot"),
    ("_loadAppSettings", "loadAppSettings"),
    ("_readOutput", "readOutput"),
    ("_appearanceThemeNotifier", "appearanceThemeNotifier"),
    ("_saveAppSettings", "saveAppSettings"),
    ("_matchRepository", "matchRepository"),
    ("_joinPath", "joinPath"),
    ("_splitCommandLine", "splitCommandLine"),
    ("_defaultPythonCommand", "defaultPythonCommand"),
    ("_defaultSvnCommand", "defaultSvnCommand"),
    ("_defaultSvnParameters", "defaultSvnParameters"),
    ("_t(", "t("),
    ("_OutputConsole", "OutputConsole"),
    ("_ControlPanel(", "ControlPanel("),
    ("_DataPanel(", "DataPanel("),
    ("_SettingsSectionCard(", "SettingsSectionCard("),
    ("_RepositoryProfilesEditor(", "RepositoryProfilesEditor("),
    ("_CommitTimelineItem(", "CommitTimelineItem("),
    ("_BranchCommitPreviewDialog(", "BranchCommitPreviewDialog("),
    ("_isNightAppearance", "isNightAppearance"),
    ("_cyberBackground", "cyberBackground"),
    ("_dayBackground", "dayBackground"),
    ("_stitchSurfaceDim", "stitchSurfaceDim"),
    ("_aura(", "aura("),
    ("_filterCommitsForBranch", "filterCommitsForBranch"),
]
for a, b in repl:
    body = body.replace(a, b)

header = """import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/branch_map_view.dart';
import 'package:aura_svn/data/data_loader.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/project_report_view.dart';
import 'package:aura_svn/settings_view.dart';
import 'package:aura_svn/utils/command_line.dart';
import 'package:aura_svn/utils/path_utils.dart';
import 'package:aura_svn/widgets/commit_widgets.dart';
import 'package:aura_svn/widgets/dashboard_widgets.dart';
import 'package:aura_svn/widgets/data_panel_widgets.dart';
import 'package:aura_svn/widgets/preview_dialog.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const SvnBranchViewerApp());
}

class SvnBranchViewerApp extends StatelessWidget {
  const SvnBranchViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appearanceThemeNotifier,
      builder: (context, appearanceThemeCode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aura SVN',
          theme: buildAuraThemeData(appearanceThemeCode),
          home: const DashboardPage(),
        );
      },
    );
  }
}

"""

out = header + body + "\n"
(root / "lib/main.dart").write_text(out, encoding="utf-8")
print("main.dart rewritten, chars", len(out))
