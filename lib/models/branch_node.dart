import 'package:aura_svn/utils/helpers.dart';

class BranchNode {
  const BranchNode({
    required this.children,
    this.kind,
    this.originRev,
    this.parent,
    this.parentRev,
    this.copyFromPath,
    this.copyFromRev,
  });

  factory BranchNode.fromJson(Map<String, dynamic> json) {
    return BranchNode(
      children: (json['children'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      kind: json['kind']?.toString(),
      originRev: asInt(json['origin_rev']),
      parent: json['parent']?.toString(),
      parentRev: asInt(json['parent_rev']),
      copyFromPath: json['copyfrom_path']?.toString(),
      copyFromRev: asInt(json['copyfrom_rev']),
    );
  }

  final List<String> children;
  final String? kind;
  final int? originRev;
  final String? parent;
  final int? parentRev;
  final String? copyFromPath;
  final int? copyFromRev;
}
