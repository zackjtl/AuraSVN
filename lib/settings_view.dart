part of 'main.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.settings,
    required this.usernameController,
    required this.passwordController,
    required this.notesRootController,
    required this.backendUrlController,
    required this.ollamaUrlController,
    required this.ollamaModelController,
    required this.ollamaApiKeyController,
    required this.svnCommandController,
    required this.svnParametersController,
    required this.pythonController,
    required this.languageCode,
    required this.onLanguageChanged,
    required this.appearanceThemeCode,
    required this.onAppearanceThemeChanged,
    required this.backendStatus,
    required this.isBackendBusy,
    required this.onSave,
    required this.onClose,
    required this.onCheckBackend,
    required this.onStartBackend,
    required this.onStopBackendProcesses,
  });

  final AppSettings settings;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController notesRootController;
  final TextEditingController backendUrlController;
  final TextEditingController ollamaUrlController;
  final TextEditingController ollamaModelController;
  final TextEditingController ollamaApiKeyController;
  final TextEditingController svnCommandController;
  final TextEditingController svnParametersController;
  final TextEditingController pythonController;
  final String languageCode;
  final ValueChanged<String> onLanguageChanged;
  final String appearanceThemeCode;
  final ValueChanged<String> onAppearanceThemeChanged;
  final String backendStatus;
  final bool isBackendBusy;
  final Future<void> Function() onSave;
  final VoidCallback onClose;
  final Future<void> Function() onCheckBackend;
  final Future<void> Function() onStartBackend;
  final Future<void> Function() onStopBackendProcesses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indexPath = notesRootController.text.trim().isEmpty
        ? '-'
        : _joinPath(notesRootController.text.trim(), 'branch_notes_index.json');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsSectionCard(
            icon: Icons.settings_rounded,
            title: _t(context, '設定', 'Settings'),
            description: _t(
              context,
              '管理介面語言、共享 Markdown 筆記、命令列、本地後端與 Ollama 設定。',
              'Manage interface language, shared Markdown notes, commands, local backend, and Ollama settings.',
            ),
            trailing: IconButton(
              tooltip: _t(context, '返回', 'Back'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
            children: [
              Text(
                _t(context, '介面語言', 'Interface Language'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'zh_TW', label: Text('繁中')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {languageCode},
                onSelectionChanged: (selection) {
                  onLanguageChanged(selection.first);
                },
              ),
              const SizedBox(height: 18),
              Text(
                _t(context, '外觀主題', 'Appearance Theme'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'night',
                    icon: const Icon(Icons.dark_mode_rounded),
                    label: Text(_t(context, '夜晚', 'Night')),
                  ),
                  ButtonSegment(
                    value: 'day',
                    icon: const Icon(Icons.light_mode_rounded),
                    label: Text(_t(context, '白天', 'Day')),
                  ),
                ],
                selected: {appearanceThemeCode},
                onSelectionChanged: (selection) {
                  onAppearanceThemeChanged(selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            icon: Icons.lock_outline_rounded,
            title: _t(context, 'SVN 認證', 'SVN Credentials'),
            description: _t(
              context,
              '可留空，使用本機 SVN 認證快取。這裡的帳號密碼只保留在目前 UI 工作階段，不會寫入設定檔。',
              'Optional. Leave blank to use the local SVN credential cache. These credentials are kept only in the current UI session and are not written to the settings file.',
            ),
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'SVN Username',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'SVN Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            icon: Icons.folder_shared_rounded,
            title: _t(context, '共享筆記目錄', 'Shared Notes Directory'),
            description: _t(
              context,
              '請指定一個所有團隊成員都能存取的固定根目錄。每台 client 指向同一個資料夾後，就會讀寫同一批分支 Markdown 筆記。',
              'Choose a shared root folder accessible to the team. Clients pointing to the same folder will read and write the same branch Markdown notes.',
            ),
            children: [
              TextField(
                controller: notesRootController,
                decoration: InputDecoration(
                  labelText: _t(
                    context,
                    'Markdown 筆記根目錄',
                    'Markdown Notes Root',
                  ),
                  hintText: _t(
                    context,
                    r'例如：\\server\share\SVNBranchNotes',
                    r'Example: \\server\share\SVNBranchNotes',
                  ),
                  prefixIcon: const Icon(Icons.folder_shared_rounded),
                ),
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: _t(context, '目前設定', 'Current Setting'),
                value: settings.notesRootPath,
              ),
              const SizedBox(height: 8),
              _InfoLine(label: 'Index', value: indexPath),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            icon: Icons.terminal_rounded,
            title: _t(context, '命令列設定', 'Command Settings'),
            description: _t(
              context,
              '這些值會套用到 Flutter 的增量更新與本地後端啟動；後端的受控 SVN tools 也會讀取同一份設定作為預設值。',
              'These values are used by Flutter incremental updates and local backend startup. Controlled backend SVN tools read the same settings as defaults.',
            ),
            children: [
              TextField(
                controller: svnCommandController,
                decoration: const InputDecoration(
                  labelText: 'SVN Command',
                  prefixIcon: Icon(Icons.source_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: svnParametersController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'SVN Command Parameters',
                  helperText: _t(
                    context,
                    '可用空白或換行分隔，例如 --non-interactive 與 trust-server-cert 參數。',
                    'Separate by spaces or new lines, for example --non-interactive and trust-server-cert options.',
                  ),
                  prefixIcon: const Icon(Icons.tune_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pythonController,
                decoration: const InputDecoration(
                  labelText: 'Python Command',
                  prefixIcon: Icon(Icons.terminal_rounded),
                ),
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: _t(context, '預設 SVN', 'Default SVN'),
                value: _defaultSvnCommand(),
              ),
              const SizedBox(height: 8),
              _InfoLine(
                label: _t(context, '預設參數', 'Default Parameters'),
                value: _defaultSvnParameters(),
              ),
              const SizedBox(height: 8),
              _InfoLine(
                label: _t(context, '預設 Python', 'Default Python'),
                value: _defaultPythonCommand(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            icon: Icons.dns_rounded,
            title: _t(context, '本地後端與 Ollama', 'Local Backend and Ollama'),
            description: _t(
              context,
              'Flutter client 會透過本地 Python 後端讀寫筆記、產生專案報告，後端再呼叫 Ollama 與受控 SVN tools。Ollama API Key 由本頁設定，不再讀取專案根目錄 .env。',
              'The Flutter client uses the local Python backend to read/write notes and generate reports. The backend calls Ollama and controlled SVN tools. Configure the Ollama API key here; project .env files are no longer read.',
            ),
            children: [
              TextField(
                controller: backendUrlController,
                decoration: InputDecoration(
                  labelText: _t(context, '本地後端 URL', 'Local Backend URL'),
                  hintText: 'http://127.0.0.1:8765',
                  prefixIcon: const Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _aura(context).surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _aura(context).border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        backendStatus,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: isBackendBusy ? null : onCheckBackend,
                    icon: isBackendBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.health_and_safety_rounded),
                    label: Text(_t(context, '檢查狀態', 'Check Status')),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBackendBusy ? null : onStartBackend,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(_t(context, '啟動本地後端', 'Start Local Backend')),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBackendBusy ? null : onStopBackendProcesses,
                    icon: const Icon(Icons.stop_circle_rounded),
                    label:
                        Text(_t(context, '關閉舊 process', 'Close Old Processes')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ollamaUrlController,
                decoration: InputDecoration(
                  labelText: 'Ollama Base URL',
                  hintText: _t(
                    context,
                    '例如：http://localhost:11434 或雲端 Ollama URL',
                    'Example: http://localhost:11434 or a cloud Ollama URL',
                  ),
                  prefixIcon: const Icon(Icons.memory_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ollamaModelController,
                decoration: const InputDecoration(
                  labelText: 'Ollama Model',
                  hintText: 'qwen3-coder-next',
                  prefixIcon: Icon(Icons.smart_toy_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ollamaApiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Ollama API Key',
                  hintText: _t(
                    context,
                    '雲端 Ollama 需要時填入；本機無認證可留空',
                    'Required for cloud Ollama; leave blank for local unauthenticated servers',
                  ),
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t(
                          context,
                          '安全提醒：API Key 會以明文儲存在本機 .runtime_configs/app_settings.json，僅建議用於受信任電腦。若此專案資料夾會分享、同步或提交版本控制，請先確認該檔案不會外流。',
                          'Security reminder: The API key is stored as plain text in local .runtime_configs/app_settings.json. Use this only on trusted machines. If this project folder is shared, synced, or committed to version control, make sure the file will not leak.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            icon: Icons.save_rounded,
            title: _t(context, '儲存與資料格式', 'Save and Storage Layout'),
            description: _t(
              context,
              '儲存後會套用設定並返回主頁。',
              'Saving applies settings and returns to the home page.',
            ),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_t(context, '儲存設定', 'Save Settings')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(_t(context, '返回資料檢視', 'Back to Data View')),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _aura(context).surfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _aura(context).border),
                ),
                child: const SelectableText(
                  'notes_root/\n'
                  '  branch_notes_index.json\n'
                  '  ET1289_AP/\n'
                  '    branches/\n'
                  '      BR263.md',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _aura(context).textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RepositoryProfilesEditor extends StatefulWidget {
  const _RepositoryProfilesEditor({
    required this.repositories,
    required this.onChanged,
  });

  final List<SvnRepository> repositories;
  final ValueChanged<List<SvnRepository>> onChanged;

  @override
  State<_RepositoryProfilesEditor> createState() =>
      _RepositoryProfilesEditorState();
}

class _RepositoryProfilesEditorState extends State<_RepositoryProfilesEditor> {
  final _drafts = <_RepositoryProfileDraft>[];

  @override
  void initState() {
    super.initState();
    _replaceDrafts(widget.repositories);
  }

  @override
  void didUpdateWidget(covariant _RepositoryProfilesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_profilesEqual(widget.repositories, _toRepositories())) {
      _replaceDrafts(widget.repositories);
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _replaceDrafts(List<SvnRepository> repositories) {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts
      ..clear()
      ..addAll(repositories.map(_RepositoryProfileDraft.fromRepository));
  }

  List<SvnRepository> _toRepositories() {
    return _drafts
        .map((draft) => SvnRepository(
              draft.title.text.trim(),
              draft.url.text.trim(),
              subtitle: draft.subtitle.text.trim(),
            ))
        .toList();
  }

  void _emitChanged() {
    widget.onChanged(_toRepositories());
  }

  void _addProfile() {
    setState(() {
      _drafts.add(_RepositoryProfileDraft.empty());
    });
    _emitChanged();
  }

  void _deleteProfile(int index) {
    if (_drafts.length <= 1) {
      return;
    }
    setState(() {
      _drafts.removeAt(index).dispose();
    });
    _emitChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _t(context, 'Repository Profiles', 'Repository Profiles'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _addProfile,
              icon: const Icon(Icons.add_rounded),
              label: Text(_t(context, '新增庫', 'Add Repository')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            context,
            '可新增或刪除 SVN 庫。Title 與 SVN Base URL 必填；Sub Title 可留空。',
            'Add or remove SVN repositories. Title and SVN Base URL are required; Sub Title is optional.',
          ),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: _aura(context).textMuted),
        ),
        const SizedBox(height: 14),
        ..._drafts.asMap().entries.map((entry) {
          final index = entry.key;
          final draft = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _aura(context).surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _aura(context).border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_t(context, 'Profile', 'Profile')} ${index + 1}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _t(context, '刪除', 'Delete'),
                        onPressed: _drafts.length <= 1
                            ? null
                            : () => _deleteProfile(index),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: draft.title,
                    onChanged: (_) => _emitChanged(),
                    decoration: InputDecoration(
                      labelText: _t(context, 'Title（必填）', 'Title (required)'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: draft.subtitle,
                    onChanged: (_) => _emitChanged(),
                    decoration: InputDecoration(
                      labelText: _t(
                        context,
                        'Sub Title（可留空）',
                        'Sub Title (optional)',
                      ),
                      prefixIcon: const Icon(Icons.short_text_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: draft.url,
                    onChanged: (_) => _emitChanged(),
                    decoration: InputDecoration(
                      labelText: _t(
                        context,
                        'SVN Base URL（必填）',
                        'SVN Base URL (required)',
                      ),
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RepositoryProfileDraft {
  _RepositoryProfileDraft({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  factory _RepositoryProfileDraft.fromRepository(SvnRepository repository) {
    return _RepositoryProfileDraft(
      title: TextEditingController(text: repository.name),
      subtitle: TextEditingController(text: repository.subtitle),
      url: TextEditingController(text: repository.url),
    );
  }

  factory _RepositoryProfileDraft.empty() {
    return _RepositoryProfileDraft(
      title: TextEditingController(),
      subtitle: TextEditingController(),
      url: TextEditingController(),
    );
  }

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController url;

  void dispose() {
    title.dispose();
    subtitle.dispose();
    url.dispose();
  }
}

bool _profilesEqual(
  List<SvnRepository> repositories,
  List<SvnRepository> other,
) {
  if (repositories.length != other.length) {
    return false;
  }
  for (var i = 0; i < repositories.length; i += 1) {
    if (repositories[i].name != other[i].name ||
        repositories[i].subtitle != other[i].subtitle ||
        repositories[i].url != other[i].url) {
      return false;
    }
  }
  return true;
}
