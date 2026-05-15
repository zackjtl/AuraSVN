bool isTrunkPath(String path) {
  return path == '/trunk' || path.contains('/trunk');
}

/// 組出 SVN checkout 用的完整 URL：`[repositoryBaseUrl]` + [branchPath]（如 `/trunk/...`）。
String svnCheckoutUrlForBranch(String repositoryBaseUrl, String branchPath) {
  final base = repositoryBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final p = branchPath.trim();
  if (p.isEmpty) {
    return repositoryBaseUrl.trim();
  }
  final suffix = p.startsWith('/') ? p : '/$p';
  return '$base$suffix';
}
