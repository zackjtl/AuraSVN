import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/path_utils.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:flutter/material.dart';

/// 將欄位標題放在輸入框上方，避免與 outline 內文字或 floating label 重疊。
class _SettingsLabeledField extends StatelessWidget {
  const _SettingsLabeledField({
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.minLines,
    this.maxLines,
    this.helperText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;
  final String? helperText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: aura(context).text,
            letterSpacing: 0,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          minLines: obscureText ? null : minLines,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            helperText: helperText,
          ),
        ),
      ],
    );
  }
}

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
    required this.onTestOllama,
    required this.isOllamaTestBusy,
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
  final Future<void> Function() onTestOllama;
  final bool isOllamaTestBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indexPath = notesRootController.text.trim().isEmpty
        ? '-'
        : joinPath(notesRootController.text.trim(), 'branch_notes_index.json');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionCard(
            icon: Icons.settings_rounded,
            title: t(context, '設定', 'Settings'),
            description: t(
              context,
              '管理介面語言、共享 Markdown 筆記、命令列、本地後端與 LLM 設定。',
              'Manage interface language, shared Markdown notes, commands, local backend, and LLM settings.',
            ),
            trailing: OutlinedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(t(context, '返回', 'Back')),
            ),
            children: [
              Text(
                t(context, '介面語言', 'Interface Language'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
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
                t(context, '外觀主題', 'Appearance Theme'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'night',
                    icon: const Icon(Icons.dark_mode_rounded),
                    label: Text(t(context, '夜晚', 'Night')),
                  ),
                  ButtonSegment(
                    value: 'day',
                    icon: const Icon(Icons.light_mode_rounded),
                    label: Text(t(context, '白天', 'Day')),
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
          SettingsSectionCard(
            icon: Icons.lock_outline_rounded,
            title: t(context, 'SVN 認證', 'SVN Credentials'),
            description: t(
              context,
              '可留空，使用本機 SVN 認證快取。這裡的帳號密碼只保留在目前 UI 工作階段，不會寫入設定檔。',
              'Optional. Leave blank to use the local SVN credential cache. These credentials are kept only in the current UI session and are not written to the settings file.',
            ),
            children: [
              _SettingsLabeledField(
                label: 'SVN Username',
                controller: usernameController,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(height: 12),
              _SettingsLabeledField(
                label: 'SVN Password',
                controller: passwordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            icon: Icons.folder_shared_rounded,
            title: t(context, '共享筆記目錄', 'Shared Notes Directory'),
            description: t(
              context,
              '請指定一個所有團隊成員都能存取的固定根目錄。每台 client 指向同一個資料夾後，就會讀寫同一批分支 Markdown 筆記。',
              'Choose a shared root folder accessible to the team. Clients pointing to the same folder will read and write the same branch Markdown notes.',
            ),
            children: [
              _SettingsLabeledField(
                label: t(
                  context,
                  'Markdown 筆記根目錄',
                  'Markdown Notes Root',
                ),
                controller: notesRootController,
                hintText: t(
                  context,
                  r'例如：\\server\share\SVNBranchNotes',
                  r'Example: \\server\share\SVNBranchNotes',
                ),
                prefixIcon: const Icon(Icons.folder_shared_rounded),
              ),
              const SizedBox(height: 14),
              InfoLine(
                label: t(context, '目前設定', 'Current Setting'),
                value: settings.notesRootPath,
              ),
              const SizedBox(height: 8),
              InfoLine(label: 'Index', value: indexPath),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            icon: Icons.terminal_rounded,
            title: t(context, '命令列設定', 'Command Settings'),
            description: t(
              context,
              '這些值會套用到 Flutter 的增量更新與本地後端啟動；後端的受控 SVN tools 也會讀取同一份設定作為預設值。',
              'These values are used by Flutter incremental updates and local backend startup. Controlled backend SVN tools read the same settings as defaults.',
            ),
            children: [
              _SettingsLabeledField(
                label: 'SVN Command',
                controller: svnCommandController,
                prefixIcon: const Icon(Icons.source_rounded),
              ),
              const SizedBox(height: 12),
              _SettingsLabeledField(
                label: 'SVN Command Parameters',
                controller: svnParametersController,
                minLines: 1,
                maxLines: 3,
                helperText: t(
                  context,
                  '可用空白或換行分隔，例如 --non-interactive 與 trust-server-cert 參數。',
                  'Separate by spaces or new lines, for example --non-interactive and trust-server-cert options.',
                ),
                prefixIcon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(height: 12),
              _SettingsLabeledField(
                label: 'Python Command',
                controller: pythonController,
                prefixIcon: const Icon(Icons.terminal_rounded),
              ),
              const SizedBox(height: 14),
              InfoLine(
                label: t(context, '預設 SVN', 'Default SVN'),
                value: defaultSvnCommand(),
              ),
              const SizedBox(height: 8),
              InfoLine(
                label: t(context, '預設參數', 'Default Parameters'),
                value: defaultSvnParameters(),
              ),
              const SizedBox(height: 8),
              InfoLine(
                label: t(context, '預設 Python', 'Default Python'),
                value: defaultPythonCommand(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            icon: Icons.dns_rounded,
            title: t(context, '本地後端與 LLM', 'Local Backend and LLM'),
            description: t(
              context,
              'Flutter client 會透過本地 Python 後端讀寫筆記、產生專案報告，後端再呼叫 LLM 與受控 SVN tools。LLM API Key 由本頁設定，不再讀取專案根目錄 .env。',
              'The Flutter client uses the local Python backend to read/write notes and generate reports. The backend calls LLM and controlled SVN tools. Configure the LLM API key here; project .env files are no longer read.',
            ),
            children: [
              _SettingsLabeledField(
                label: t(context, '本地後端 URL', 'Local Backend URL'),
                controller: backendUrlController,
                hintText: 'http://127.0.0.1:8765',
                prefixIcon: const Icon(Icons.dns_rounded),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: aura(context).surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: aura(context).border),
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
                          fontWeight: FontWeight.w600,
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
                    label: Text(t(context, '檢查狀態', 'Check Status')),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBackendBusy ? null : onStartBackend,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(t(context, '啟動本地後端', 'Start Local Backend')),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBackendBusy ? null : onStopBackendProcesses,
                    icon: const Icon(Icons.stop_circle_rounded),
                    label:
                        Text(t(context, '關閉舊 process', 'Close Old Processes')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsLabeledField(
                label: 'LLM Base URL',
                controller: ollamaUrlController,
                hintText: t(
                  context,
                  '例如：http://localhost:11434 或雲端 LLM URL',
                  'Example: http://localhost:11434 or a cloud LLM URL',
                ),
                prefixIcon: const Icon(Icons.memory_rounded),
              ),
              const SizedBox(height: 12),
              _SettingsLabeledField(
                label: 'LLM Model',
                controller: ollamaModelController,
                hintText: 'qwen3-coder-next',
                prefixIcon: const Icon(Icons.smart_toy_rounded),
              ),
              const SizedBox(height: 12),
              _SettingsLabeledField(
                label: 'LLM API Key',
                controller: ollamaApiKeyController,
                obscureText: true,
                hintText: t(
                  context,
                  '雲端 LLM 需要時填入；本機無認證可留空',
                  'Required for cloud LLM; leave blank for local unauthenticated servers',
                ),
                prefixIcon: const Icon(Icons.key_rounded),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: (isBackendBusy || isOllamaTestBusy)
                        ? null
                        : onTestOllama,
                    icon: isOllamaTestBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.science_outlined),
                    label: Text(
                      t(context, '測試 LLM 連線', 'Test LLM Connection'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  context,
                  '使用目前欄位內容（可不先儲存），由本地後端代為呼叫 LLM；請先啟動後端並確認 URL／Model／API Key 正確。',
                  'Uses the current field values (no need to save first); the local backend calls LLM on your behalf. Start the backend and verify URL, model, and API key.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: aura(context).textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF241800)
                      : const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF5C3A00)
                        : const Color(0xFFE57A5A),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF79A8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t(
                          context,
                          '安全提醒：API Key 會以明文儲存在本機 .runtime_configs/app_settings.json，僅建議用於受信任電腦。若此專案資料夾會分享、同步或提交版本控制，請先確認該檔案不會外流。',
                          'Security reminder: The API key is stored as plain text in local .runtime_configs/app_settings.json. Use this only on trusted machines. If this project folder is shared, synced, or committed to version control, make sure the file will not leak.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFF79A8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            icon: Icons.save_rounded,
            title: t(context, '儲存與資料格式', 'Save and Storage Layout'),
            description: t(
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
                    label: Text(t(context, '儲存設定', 'Save Settings')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(t(context, '返回', 'Back')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
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
                    color: theme.colorScheme.primary.withOpacity(0.10),
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
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: aura(context).textMuted,
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

class RepositoryProfilesEditor extends StatefulWidget {
  const RepositoryProfilesEditor({
    required this.repositories,
    required this.onChanged,
  });

  final List<SvnRepository> repositories;
  final ValueChanged<List<SvnRepository>> onChanged;

  @override
State<RepositoryProfilesEditor> createState() =>
      RepositoryProfilesEditorState();
}

class RepositoryProfilesEditorState extends State<RepositoryProfilesEditor> {
  final _drafts = <_RepositoryProfileDraft>[];

  @override
  void initState() {
    super.initState();
    _replaceDrafts(widget.repositories);
  }

  @override
  void didUpdateWidget(covariant RepositoryProfilesEditor oldWidget) {
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
        .where((r) => r.name.isNotEmpty && r.url.isNotEmpty)
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
    setState(() {
      _drafts.removeAt(index).dispose();
    });
    _emitChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileTileFill =
        isDark ? cyberSurfaceSoft : aura(context).surfaceAlt;

    final fieldTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: aura(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _addProfile,
            icon: const Icon(Icons.add_rounded),
            label: Text(t(context, '新增庫', 'Add Repository')),
          ),
        ),
        const SizedBox(height: 14),
        if (_drafts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            decoration: BoxDecoration(
              color: profileTileFill,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: aura(context).border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: aura(context).textSubtle,
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    context,
                    '尚未設定任何 Repository',
                    'No repositories configured',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: aura(context).textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    context,
                    '請按「新增庫」建立第一個 Profile，或儲存以清空清單。',
                    'Use Add Repository to create one, or save to keep an empty list.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: aura(context).textSubtle,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ..._drafts.asMap().entries.map((entry) {
          final index = entry.key;
          final draft = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: profileTileFill,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: aura(context).border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_special_rounded,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${t(context, 'Profile', 'Profile')} ${index + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                            height: 1.2,
                            color: aura(context).text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: t(context, '刪除', 'Delete'),
                        onPressed: () => _deleteProfile(index),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: Colors.red,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: aura(context).border.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: fieldTheme,
                    child: Column(
                      children: [
                        _SettingsLabeledField(
                          label: t(
                              context, 'Title（必填）', 'Title (required)'),
                          controller: draft.title,
                          prefixIcon: const Icon(Icons.badge_outlined),
                          onChanged: (_) => _emitChanged(),
                        ),
                        const SizedBox(height: 10),
                        _SettingsLabeledField(
                          label: t(
                            context,
                            'Sub Title（可留空）',
                            'Sub Title (optional)',
                          ),
                          controller: draft.subtitle,
                          prefixIcon: const Icon(Icons.short_text_rounded),
                          onChanged: (_) => _emitChanged(),
                        ),
                        const SizedBox(height: 10),
                        _SettingsLabeledField(
                          label: t(
                            context,
                            'SVN Base URL（必填）',
                            'SVN Base URL (required)',
                          ),
                          controller: draft.url,
                          prefixIcon: const Icon(Icons.link_rounded),
                          onChanged: (_) => _emitChanged(),
                        ),
                      ],
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
