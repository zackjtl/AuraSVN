import pathlib

subs = [
    ("_DataPanelTopLeakDivider", "DataPanelTopLeakDivider"),
    ("_DataPanel", "DataPanel"),
    ("_TopologyCard", "TopologyCard"),
    ("_TopologyNodeTile", "TopologyNodeTile"),
    ("_MetricCard", "MetricCard"),
    ("_BackendStatusCard", "BackendStatusCard"),
    ("_ErrorBanner", "ErrorBanner"),
    ("_EmptyDataCard", "EmptyDataCard"),
    ("_metricStripLeft", "metricStripLeft"),
    ("_stitchPrimaryFixed", "stitchPrimaryFixed"),
    ("_stitchSurfaceDim", "stitchSurfaceDim"),
    ("_aura(", "aura("),
    ("_t(", "t("),
    ("_isTrunkPath", "isTrunkPath"),
    ("_SmallChip", "SmallChip"),
    ("_InfoLine", "InfoLine"),
    ("_cyberAccent", "cyberAccent"),
    ("_cyberBackground", "cyberBackground"),
    ("_dashboardStatStripDecoration", "dashboardStatStripDecoration"),
]


def xform(s: str) -> str:
    for a, b in subs:
        s = s.replace(a, b)
    return s


data_header = """import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/branch_map_view.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/branch_node.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/branch_paths.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/status_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

"""

commit_header = """import 'dart:ui' show FontFeature;

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/diff/diff_widgets.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/commit_record.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/helpers.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

"""

commit_subs = subs + [
    ("_CommitTimelineItem", "CommitTimelineItem"),
    ("_TimelineRailPainter", "TimelineRailPainter"),
    ("_CommitTile", "CommitTile"),
    ("_CommitTileState", "CommitTileState"),
    ("_RevisionDiffDialog", "RevisionDiffDialog"),
    ("_loadRevisionDiff", "loadRevisionDiff"),
    ("_actionColor", "actionColor"),
    ("_shortCommitDate", "shortCommitDate"),
]


def xform_commit(s: str) -> str:
    for a, b in commit_subs:
        s = s.replace(a, b)
    return s


def main() -> None:
    root = pathlib.Path(__file__).resolve().parents[1]
    body = xform((root / "lib/_extract_data_panel.dart").read_text(encoding="utf-8"))
    (root / "lib/widgets/data_panel_widgets.dart").write_text(
        data_header + body, encoding="utf-8"
    )

    topo = xform((root / "lib/_extract_topology.dart").read_text(encoding="utf-8"))
    tile = xform_commit((root / "lib/_extract_commit_tile.dart").read_text(encoding="utf-8"))
    (root / "lib/widgets/commit_widgets.dart").write_text(
        commit_header + topo + "\n" + tile, encoding="utf-8"
    )

    dash_subs = subs + [
        ("_ControlPanel", "ControlPanel"),
        ("_RepositorySelector", "RepositorySelector"),
        ("_RepositorySelectorState", "RepositorySelectorState"),
        ("_AuraBrandMark", "AuraBrandMark"),
        ("_OutputConsole", "OutputConsole"),
        ("_RepositoryTile", "RepositoryTile"),
        ("_StatusPill", "StatusPill"),
    ]

    def xd(s: str) -> str:
        for a, b in dash_subs:
            s = s.replace(a, b)
        return s

    dash_header = """import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/status_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

"""
    dash_body = xd((root / "lib/_extract_dashboard.txt").read_text(encoding="utf-8"))
    (root / "lib/widgets/dashboard_widgets.dart").write_text(
        dash_header + dash_body, encoding="utf-8"
    )
    print("wrote data_panel_widgets, commit_widgets, dashboard_widgets")


if __name__ == "__main__":
    main()
