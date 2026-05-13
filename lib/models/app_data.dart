import 'package:aura_svn/models/branch_node.dart';
import 'package:aura_svn/models/commit_record.dart';

class AppData {
  const AppData({
    required this.topology,
    required this.commits,
    required this.shardNames,
  });

  factory AppData.empty() => const AppData(
        topology: {},
        commits: [],
        shardNames: [],
      );

  final Map<String, BranchNode> topology;
  final List<CommitRecord> commits;
  final List<String> shardNames;

  bool get isEmpty => topology.isEmpty && commits.isEmpty;

  CommitRecord? get latestCommit => commits.isEmpty ? null : commits.first;
}
