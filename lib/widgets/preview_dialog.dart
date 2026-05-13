import 'dart:ui';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/commit_record.dart';
import 'package:aura_svn/utils/helpers.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:flutter/material.dart';

class BranchCommitPreviewDialog extends StatelessWidget {
  const BranchCommitPreviewDialog({
    super.key,
    required this.branchPath,
    required this.commits,
  });

  final String branchPath;
  final List<CommitRecord> commits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: aura(context).surface.withOpacity(0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.34),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.14),
                  blurRadius: 34,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.38),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 920,
                maxHeight: size.height * 0.82,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.14),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t(context, 'Branch Commit 預覽',
                                    'Branch Commit Preview'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SelectableText(
                                branchPath,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: aura(context).textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          avatar:
                              const Icon(Icons.receipt_long_rounded, size: 18),
                          label: Text('${commits.length} commits'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: commits.isEmpty
                          ? Center(
                              child: Text(t(
                                context,
                                '找不到此 branch 相關 commit。',
                                'No commits found for this branch.',
                              )),
                            )
                          : ListView.separated(
                              itemCount: commits.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final commit = commits[index];
                                return BranchCommitPreviewTile(commit: commit);
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(t(context, '關閉', 'Close')),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(t(context, '詳情', 'Details')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BranchCommitPreviewTile extends StatelessWidget {
  const BranchCommitPreviewTile({super.key, required this.commit});

  final CommitRecord commit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = commit.message.trim().isEmpty
        ? t(context, '(無 commit message)', '(No commit message)')
        : commit.message.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: aura(context).border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RevisionText(revision: commit.revision),
                    if (commit.author.isNotEmpty)
                      MiniMetaChip(
                        icon: Icons.person_outline_rounded,
                        label: commit.author,
                      ),
                    if (commit.date.isNotEmpty)
                      MiniMetaChip(
                        icon: Icons.schedule_rounded,
                        label: shortCommitDate(commit.date),
                      ),
                    MiniMetaChip(
                      icon: Icons.edit_rounded,
                      label: '${commit.changedPaths.length} paths',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: aura(context).textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
