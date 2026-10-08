import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:path_provider/path_provider.dart';

const Color kPrimary = Color(0xFF2563EB);
const Color kBg = Color(0xFFF8F9FC);
const Color kTextDark = Color(0xFF111827);
const Color kTextMid = Color(0xFF3F4756);
const Color kTextLight = Color(0xFF8A94A6);
const Color kBorder = Color(0xFFEDF0F5);

void main() => runApp(const DocProApp());

// ═══ MODELS ═══
class DocFile {
  final String name, size, date;
  final IconData icon;
  final Color color;
  final bool isDraft;
  final String? path;
  DocFile({
    required this.name,
    required this.size,
    required this.date,
    required this.icon,
    required this.color,
    this.isDraft = false,
    this.path,
  });
}

class Tool {
  final String id, label, category, description;
  final IconData icon;
  final Color color;
  const Tool(this.id, this.label, this.icon, this.color, this.category, this.description);
}

class PdfImage {
  final String id;
  String name;
  Color color;
  IconData icon;
  double rotation;
  final String? path;
  PdfImage({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.rotation = 0,
    this.path,
  });
}

class PageSize {
  final String name;
  final double width, height;
  final IconData icon;
  const PageSize(this.name, this.width, this.height, this.icon);
}

const List<PageSize> kPageSizes = [
  PageSize('A4', 210, 297, Icons.description),
  PageSize('A5', 148, 210, Icons.article),
  PageSize('Instagram Post', 1080, 1080, Icons.photo_camera),
  PageSize('Instagram Story', 1080, 1920, Icons.auto_stories),
  PageSize('Facebook Post', 1200, 630, Icons.facebook),
  PageSize('Twitter Post', 1200, 675, Icons.tag),
  PageSize('YouTube Thumb', 1280, 720, Icons.play_circle_fill),
  PageSize('LinkedIn Post', 1200, 627, Icons.work),
];

class CanvaElement {
  final String id;
  Offset position;
  Size size;
  String type;
  String? text;
  String? emoji;
  String? imagePath;
  Color color;
  double fontSize;
  CanvaElement({
    required this.id,
    required this.position,
    required this.size,
    required this.type,
    this.text,
    this.emoji,
    this.imagePath,
    this.color = Colors.black,
    this.fontSize = 20,
  });
}

class OcrTextBox {
  final String id;
  Offset position;
  Size size;
  String text;
  OcrTextBox({required this.id, required this.position, required this.size, required this.text});
}

// ═══ APP STATE ═══
class AppState extends ChangeNotifier {
  final List<DocFile> recentFiles = [];
  final List<DocFile> createdFiles = [];
  final List<DocFile> drafts = [];
  int edits = 9, streak = 3, points = 0;
  bool isPro = false, darkMode = false, adsEnabled = true, notifications = true, autoBackup = true;
  double usedGB = 1.2, totalGB = 64.0;

  double get usedPct => (usedGB / totalGB).clamp(0.0, 1.0);
  double get availableGB => totalGB - usedGB;

  void useEdit() {
    if (!isPro && edits > 0) {
      edits--;
      notifyListeners();
    }
  }

  void addEdits(int n) {
    edits += n;
    notifyListeners();
  }

  void addCreated(DocFile f) {
    createdFiles.insert(0, f);
    recentFiles.insert(0, f);
    usedGB += 0.02;
    if (recentFiles.length > 6) recentFiles.removeLast();
    notifyListeners();
  }

  void addDraft(DocFile f) {
    drafts.insert(0, f);
    usedGB += 0.01;
    notifyListeners();
  }

  void deleteCreated(int i) {
    createdFiles.removeAt(i);
    notifyListeners();
  }

  void deleteDraft(int i) {
    drafts.removeAt(i);
    notifyListeners();
  }

  void deleteRecent(int i) {
    recentFiles.removeAt(i);
    notifyListeners();
  }

  void toggleDark() {
    darkMode = !darkMode;
    notifyListeners();
  }

  void toggleAds() {
    adsEnabled = !adsEnabled;
    notifyListeners();
  }

  void toggleNotifications() {
    notifications = !notifications;
    notifyListeners();
  }

  void toggleBackup() {
    autoBackup = !autoBackup;
    notifyListeners();
  }

  void buyPro() {
    isPro = true;
    notifyListeners();
  }
}

final appState = AppState();

const List<Tool> allTools = [
  Tool('scanner', 'Document Scanner', Icons.document_scanner_outlined, Color(0xFF2563EB), 'Scan', 'Scan documents'),
  Tool('idscan', 'ID Card Scan', Icons.badge_outlined, Color(0xFF10B981), 'Scan', 'Scan ID cards'),
  Tool('img2pdf', 'Image to PDF', Icons.image_outlined, Color(0xFFF59E0B), 'Scan', 'Convert images to PDF'),
  Tool('canva', 'Mini Canva', Icons.design_services_outlined, Color(0xFF8B5CF6), 'Scan', 'Create documents'),
  Tool('pdf2img', 'PDF to Image', Icons.photo_library_outlined, Color(0xFF14B8A6), 'Convert', 'PDF to images'),
  Tool('ocr', 'Image Text Edit', Icons.text_fields, Color(0xFFEF4444), 'Convert', 'Extract text'),
  Tool('enhancer', 'Document Enhancer', Icons.auto_fix_high_outlined, Color(0xFF6366F1), 'Convert', 'Enhance scans'),
  Tool('merge', 'Merge PDF', Icons.merge_type, Color(0xFF3B82F6), 'Organize', 'Merge PDFs'),
  Tool('split', 'Split PDF', Icons.call_split, Color(0xFFEF4444), 'Organize', 'Split PDF'),
  Tool('compress', 'Compress PDF', Icons.compress, Color(0xFF14B8A6), 'Organize', 'Compress PDF'),
  Tool('extract', 'Extract / Reorder', Icons.reorder, Color(0xFFEC4899), 'Organize', 'Extract pages'),
  Tool('repair', 'PDF Repair', Icons.build_outlined, Color(0xFFA16207), 'Organize', 'Fix PDFs'),
  Tool('esign', 'e-Sign PDF', Icons.draw_outlined, Color(0xFF10B981), 'Secure', 'Sign PDFs'),
  Tool('password', 'Password Protect', Icons.lock_outline, Color(0xFFEF4444), 'Secure', 'Password protect'),
  Tool('watermark', 'Watermark', Icons.branding_watermark_outlined, Color(0xFF3B82F6), 'Secure', 'Add watermark'),
  Tool('encrypt', 'File Encryption', Icons.enhanced_encryption_outlined, Color(0xFF8B5CF6), 'Secure', 'Encrypt files'),
  Tool('bcard', 'Business Card Scan', Icons.contact_page_outlined, Color(0xFFF59E0B), 'Secure', 'Scan cards'),
  Tool('search', 'Full-Text Search', Icons.search, Color(0xFF06B6D4), 'Search', 'Search text'),
];

class DocProApp extends StatelessWidget {
  const DocProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Doc Pro',
        themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.dark),
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.darkMode;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
          body: IndexedStack(
            index: _index,
            children: const [HomeTab(), FilesTab(), SettingsTab()],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111C33) : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF1E293B) : kBorder),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    _NavItem(icon: Icons.home_rounded, label: 'Home', active: _index == 0, onTap: () => setState(() => _index = 0)),
                    _NavItem(icon: Icons.folder_outlined, label: 'My Files', active: _index == 1, onTap: () => setState(() => _index = 1)),
                    _NavItem(icon: Icons.settings_outlined, label: 'Settings', active: _index == 2, onTap: () => setState(() => _index = 2)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = active ? kPrimary : (appState.darkMode ? const Color(0xFF7A8699) : const Color(0xFF9AA3B2));
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

// ═══ HOME TAB ═══
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    final cardBg = isDark ? const Color(0xFF111C33) : Colors.white;
    return Column(
      children: [
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doc Pro', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : kTextDark, height: 1.1)),
                    Text('All PDF Tools', style: TextStyle(fontSize: 12,
                      color: isDark ? const Color(0xFF7A8699) : kTextLight, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: kPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 16, color: kPrimary),
                      const SizedBox(width: 4),
                      Text('${appState.edits}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CircleIconBtn(icon: Icons.search_rounded, onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
                }),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const StorageCard(),
              const SizedBox(height: 22),
              const SectionTitle(title: 'Scan & Create', tag: 'Scan'),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ToolGrid(tools: allTools.where((t) => t.category == 'Scan').toList())),
              const SizedBox(height: 22),
              const SectionTitle(title: 'Convert', tag: 'Convert'),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ToolGrid(tools: allTools.where((t) => t.category == 'Convert').toList())),
              const SizedBox(height: 22),
              const SectionTitle(title: 'Organize', tag: 'Organize'),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ToolGrid(tools: allTools.where((t) => t.category == 'Organize').toList())),
              const SizedBox(height: 22),
              const SectionTitle(title: 'Edit & Secure', tag: 'Secure'),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ToolGrid(tools: allTools.where((t) => t.category == 'Secure').toList())),
              const SizedBox(height: 22),
              const SectionTitle(title: 'Recent Files', tag: 'recent'),
              const SizedBox(height: 10),
              if (appState.recentFiles.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _EmptyBox(text: 'No recent files yet'))
              else
                ...appState.recentFiles.take(4).toList().asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: RecentFileTile(
                    file: e.value,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FilePreviewScreen(file: e.value))),
                    onDelete: () => appState.deleteRecent(e.key),
                  ),
                )).toList(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══ FILES TAB ═══
class FilesTab extends StatefulWidget {
  const FilesTab({super.key});
  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  int _sub = 0;
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    final cardBg = isDark ? const Color(0xFF111C33) : Colors.white;
    final list = _sub == 0 ? appState.createdFiles : appState.drafts;
    return Column(
      children: [
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Files', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : kTextDark)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1526) : const Color(0xFFF1F4F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _SubTab(label: 'Created', active: _sub == 0, onTap: () => setState(() => _sub = 0)),
                      _SubTab(label: 'Drafts', active: _sub == 1, onTap: () => setState(() => _sub = 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_sub == 0 ? Icons.folder_open_outlined : Icons.edit_note_outlined,
                      size: 60, color: isDark ? const Color(0xFF3A4760) : const Color(0xFFBFC7D5)),
                    const SizedBox(height: 14),
                    Text(_sub == 0 ? 'No files created yet' : 'No drafts saved yet',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF7A8699) : kTextLight)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => RecentFileTile(
                  file: list[i],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FilePreviewScreen(file: list[i]))),
                  onDelete: () => _sub == 0 ? appState.deleteCreated(i) : appState.deleteDraft(i),
                ),
              ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SubTab({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? (appState.darkMode ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: active ? kPrimary : (appState.darkMode ? const Color(0xFF7A8699) : kTextLight))),
          ),
        ),
      ),
    );
  }
}

// ═══ SETTINGS TAB ═══
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    final cardBg = isDark ? const Color(0xFF111C33) : Colors.white;
    final textColor = isDark ? Colors.white : kTextDark;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile & Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: appState.isPro
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(14)),
                            child: Icon(appState.isPro ? Icons.workspace_premium : Icons.person_outline, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appState.isPro ? 'Pro Member' : 'Free User',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(appState.isPro ? 'Lifetime unlocked' : 'Upgrade for full access',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _StatChip(label: 'Edits', value: '${appState.edits}'),
                          const SizedBox(width: 8),
                          _StatChip(label: 'Streak', value: '${appState.streak}d'),
                          const SizedBox(width: 8),
                          _StatChip(label: 'Points', value: '${appState.points}'),
                        ],
                      ),
                      if (!appState.isPro) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => appState.buyPro(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, foregroundColor: kPrimary, elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Upgrade to Pro — Lifetime \$12.99',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(title: 'Preferences', children: [
          _SettingsSwitch(icon: Icons.dark_mode_outlined, color: const Color(0xFF6366F1),
            title: 'Dark Mode', value: appState.darkMode, onChanged: (_) => appState.toggleDark()),
          _SettingsSwitch(icon: Icons.notifications_outlined, color: const Color(0xFFF59E0B),
            title: 'Notifications', value: appState.notifications, onChanged: (_) => appState.toggleNotifications()),
        ]),
        _SettingsGroup(title: 'About', children: [
          _SettingsItem(icon: Icons.info_outline, color: kPrimary,
            title: 'About Doc Pro', subtitle: 'Version 1.0.0',
            onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text('Doc Pro'),
              content: const Text('All-in-One PDF Tools\n\nVersion 1.0.0\n\n100% Offline.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ))),
        ]),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroup({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.8, color: isDark ? const Color(0xFF5A6683) : kTextLight)),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111C33) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : kBorder),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SettingsItem({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : kTextDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF7A8699) : kTextLight)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? const Color(0xFF5A6683) : const Color(0xFFBFC7D5)),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitch({required this.icon, required this.color, required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : kTextDark)),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: kPrimary),
        ],
      ),
    );
  }
}

// ═══ WIDGETS ═══
class StorageCard extends StatelessWidget {
  const StorageCard({super.key});
  @override
  Widget build(BuildContext context) {
    final usedPct = appState.usedPct;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.smartphone, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              const Text('Device Storage', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
                child: Text('${(usedPct * 100).toStringAsFixed(0)}% used',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${appState.usedGB.toStringAsFixed(2)} GB',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(width: 6),
              Text('of ${appState.totalGB.toStringAsFixed(0)} GB',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${appState.availableGB.toStringAsFixed(2)} GB available',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: usedPct, minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title, tag;
  const SectionTitle({super.key, required this.title, required this.tag});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kTextDark)),
          if (tag != 'recent')
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: tag))),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('See all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kPrimary)),
              ),
            ),
        ],
      ),
    );
  }
}

class ToolGrid extends StatelessWidget {
  final List<Tool> tools;
  const ToolGrid({super.key, required this.tools});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 14, childAspectRatio: 0.72),
      itemBuilder: (context, i) => ToolTile(tool: tools[i]),
    );
  }
}

class ToolTile extends StatelessWidget {
  final Tool tool;
  const ToolTile({super.key, required this.tool});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return InkWell(
      onTap: () {
        appState.useEdit();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => toolScreenFor(tool)));
      },
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: tool.color.withOpacity(0.12), borderRadius: BorderRadius.circular(15)),
            child: Icon(tool.icon, color: tool.color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(tool.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : kTextMid)),
        ],
      ),
    );
  }
}

class RecentFileTile extends StatelessWidget {
  final DocFile file;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const RecentFileTile({super.key, required this.file, required this.onTap, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Material(
      color: isDark ? const Color(0xFF111C33) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: file.color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(file.icon, color: file.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : kTextDark)),
                    const SizedBox(height: 3),
                    Text('${file.size} · ${file.date}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF7A8699) : kTextLight)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: isDark ? const Color(0xFF7A8699) : const Color(0xFFBFC7D5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C33) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : kBorder),
      ),
      child: Center(
        child: Text(text, style: TextStyle(fontSize: 12.5,
          color: isDark ? const Color(0xFF7A8699) : kTextLight)),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 21, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151)),
      ),
    );
  }
}

Widget toolScreenFor(Tool t) {
  switch (t.id) {
    case 'canva': return const MiniCanvaScreen();
    case 'img2pdf': return const ImageToPdfScreen();
    case 'pdf2img': return const PdfToImageScreen();
    case 'ocr': return const OCRScreen();
    case 'enhancer': return const EnhancerScreen();
    case 'scanner': return const DocumentScannerScreen();
    default: return GenericToolScreen(tool: t);
  }
}

// ═══ SEARCH ═══
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    final results = _query.isEmpty
      ? <Tool>[]
      : allTools.where((t) => t.label.toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(hintText: 'Search tools...', border: InputBorder.none),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () { _controller.clear(); setState(() => _query = ''); },
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final t = results[i];
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: isDark ? const Color(0xFF111C33) : Colors.white,
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: t.color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(t.icon, color: t.color, size: 20),
            ),
            title: Text(t.label),
            subtitle: Text(t.category),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => toolScreenFor(t))),
          );
        },
      ),
    );
  }
}

class CategoryScreen extends StatelessWidget {
  final String category;
  const CategoryScreen({super.key, required this.category});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    final tools = category == 'recent' ? allTools : allTools.where((t) => t.category == category).toList();
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: Text(category == 'recent' ? 'All Tools' : '$category Tools'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ToolGrid(tools: tools),
      ),
    );
  }
}

class FilePreviewScreen extends StatelessWidget {
  final DocFile file;
  const FilePreviewScreen({super.key, required this.file});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: Text(file.name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 120,
              decoration: BoxDecoration(color: file.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Icon(file.icon, size: 50, color: file.color),
            ),
            const SizedBox(height: 20),
            Text(file.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 6),
            Text('${file.size} · ${file.date}',
              style: TextStyle(color: isDark ? const Color(0xFF7A8699) : kTextLight)),
          ],
        ),
      ),
    );
  }
}

// ═══ IMAGE TO PDF ═══
class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});
  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<PdfImage> _poolImages = [];
  final List<PdfImage> _pdfImages = [];
  int _uid = 0;

  int _rightIndex(PdfImage img) => _pdfImages.indexWhere((e) => e.id == img.id);

  Future<void> _pickFromGallery() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        _poolImages.add(PdfImage(id: 'img${_uid++}', name: f.name,
          color: const Color(0xFFE2E8F0), icon: Icons.image_outlined, path: f.path));
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (f == null) return;
    setState(() {
      _poolImages.add(PdfImage(id: 'img${_uid++}', name: f.name,
        color: const Color(0xFFE2E8F0), icon: Icons.image_outlined, path: f.path));
    });
  }

  void _showImportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: appState.darkMode ? const Color(0xFF111C33) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kPrimary),
              title: const Text('From Gallery'),
              onTap: () { Navigator.pop(context); _pickFromGallery(); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: kPrimary),
              title: const Text('From Camera'),
              onTap: () { Navigator.pop(context); _pickFromCamera(); },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAddToPdf(PdfImage img) {
    final idx = _rightIndex(img);
    setState(() {
      if (idx >= 0) {
        _pdfImages.removeAt(idx);
      } else {
        _pdfImages.add(img);
      }
    });
  }

  void _removeFromRight(int i) => setState(() => _pdfImages.removeAt(i));

  void _removeFromPool(int i) {
    final img = _poolImages[i];
    setState(() {
      _pdfImages.removeWhere((e) => e.id == img.id);
      _poolImages.removeAt(i);
    });
  }

  void _rotateRight(int i) => setState(() => _pdfImages[i].rotation += 90);

  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: Text(_poolImages.isEmpty ? 'Image to PDF' : 'Arrange (${_pdfImages.length}/${_poolImages.length})'),
        actions: [
          if (_poolImages.isNotEmpty)
            IconButton(icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: _showImportSheet),
        ],
      ),
      body: _poolImages.isEmpty ? _buildEmpty(isDark) : _buildEditor(isDark),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: _showImportSheet,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimary.withOpacity(0.35), width: 2),
                ),
                child: const Icon(Icons.add, size: 52, color: kPrimary),
              ),
            ),
            const SizedBox(height: 26),
            Text('Add / Upload Images',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 8),
            const Text('Tap + to select images from gallery or camera',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: kTextLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildPoolPanel(isDark),
              Container(width: 1, color: isDark ? const Color(0xFF1E293B) : kBorder),
              Expanded(child: _buildPdfPanel(isDark)),
            ],
          ),
        ),
        _buildBottomBar(isDark),
      ],
    );
  }

  Widget _buildPoolPanel(bool isDark) {
    return Container(
      width: 140,
      color: isDark ? const Color(0xFF0B1526) : const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('ALL · ${_poolImages.length}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF5A6683) : kTextLight)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: _poolImages.length,
              onReorder: (o, n) {
                setState(() {
                  if (n > o) n--;
                  final item = _poolImages.removeAt(o);
                  _poolImages.insert(n, item);
                });
              },
              itemBuilder: (context, i) {
                final img = _poolImages[i];
                final rIdx = _rightIndex(img);
                final inPdf = rIdx >= 0;
                return ReorderableDragStartListener(
                  key: ValueKey(img.id),
                  index: i,
                  child: _poolThumb(img, i, inPdf ? rIdx + 1 : null),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _poolThumb(PdfImage img, int i, int? num) {
    final inPdf = num != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: InkWell(
        onTap: () => _toggleAddToPdf(img),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: img.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: inPdf ? kPrimary : Colors.black12, width: inPdf ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 22, height: double.infinity,
                decoration: BoxDecoration(
                  color: inPdf ? kPrimary : Colors.black26,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                child: Center(
                  child: inPdf
                    ? Text('$num', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))
                    : const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
              Expanded(
                child: img.path != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(File(img.path!), fit: BoxFit.cover),
                    )
                  : Icon(img.icon, size: 22, color: Colors.black.withOpacity(0.45)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => _removeFromPool(i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPanel(bool isDark) {
    if (_pdfImages.isEmpty) {
      return Container(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Center(
          child: Text('Tap images on the left\nto add them to PDF',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF7A8699) : kTextLight)),
        ),
      );
    }
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.all(10),
        itemCount: _pdfImages.length,
        onReorder: (o, n) {
          setState(() {
            if (n > o) n--;
            final item = _pdfImages.removeAt(o);
            _pdfImages.insert(n, item);
          });
        },
        itemBuilder: (context, i) {
          final img = _pdfImages[i];
          return ReorderableDragStartListener(
            key: ValueKey('r_${img.id}'),
            index: i,
            child: _pdfCard(img, i),
          );
        },
      ),
    );
  }

  Widget _pdfCard(PdfImage img, int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                  child: Center(
                    child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(img.name, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                  onPressed: () => _removeFromRight(i),
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: img.rotation * 3.14159 / 180,
            child: Container(
              height: 200,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: img.color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kPrimary.withOpacity(0.3)),
              ),
              child: img.path != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(img.path!), fit: BoxFit.cover, width: double.infinity),
                  )
                : const Center(child: Icon(Icons.image, size: 60, color: Color(0x55000000))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _rotateRight(i),
                  icon: const Icon(Icons.rotate_90_degrees_cw_outlined, size: 16),
                  label: const Text('Rotate', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => _removeFromRight(i),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                  label: const Text('Remove', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C33) : Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add More', style: TextStyle(fontSize: 12)),
                onPressed: _showImportSheet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _pdfImages.isEmpty ? null : () {
                  appState.addCreated(DocFile(
                    name: 'Images_${appState.createdFiles.length + 1}.pdf',
                    size: '${(0.3 * _pdfImages.length).toStringAsFixed(1)} MB',
                    date: 'Just now',
                    icon: Icons.picture_as_pdf_outlined,
                    color: const Color(0xFFF59E0B),
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF created with ${_pdfImages.length} pages')),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                child: const Text('Create PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ PDF TO IMAGE ═══
class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});
  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  String? _pdfName, _pdfPath, _pdfSize;
  int _pdfPages = 0;
  final Set<int> _selected = {};
  String _format = 'PNG';
  bool _rendering = false;

  Future<void> _openPicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null) return;
    final path = result.files.single.path!;
    setState(() => _rendering = true);
    try {
      final doc = await pdfx.PdfDocument.openFile(path);
      setState(() {
        _pdfName = result.files.single.name;
        _pdfPath = path;
        _pdfPages = doc.pagesCount;
        _pdfSize = '${(File(path).lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB';
        _selected.clear();
        for (int i = 1; i <= _pdfPages; i++) _selected.add(i);
      });
      await doc.close();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  void _reset() => setState(() {
    _pdfName = null;
    _pdfPath = null;
    _selected.clear();
    _pdfPages = 0;
    _pdfSize = '';
  });

  void _toggleSelect(int n) => setState(() {
    if (_selected.contains(n)) {
      _selected.remove(n);
    } else {
      _selected.add(n);
    }
  });

  void _selectAll() => setState(() {
    if (_selected.length == _pdfPages) {
      _selected.clear();
    } else {
      _selected.clear();
      for (int i = 1; i <= _pdfPages; i++) _selected.add(i);
    }
  });

  Future<void> _download() async {
    if (_selected.isEmpty || _pdfPath == null) return;
    setState(() => _rendering = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final doc = await pdfx.PdfDocument.openFile(_pdfPath!);
      for (final n in _selected) {
        final page = await doc.getPage(n);
        final image = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: _format == 'PNG' ? pdfx.PdfPageImageFormat.png : pdfx.PdfPageImageFormat.jpeg,
        );
        if (image != null) {
          await File('${dir.path}/${_pdfName!.replaceAll('.pdf', '')}_page_$n.${_format.toLowerCase()}')
            .writeAsBytes(image.bytes);
        }
        await page.close();
      }
      await doc.close();
      if (!mounted) return;
      appState.addCreated(DocFile(
        name: '${_pdfName!.replaceAll('.pdf', '')}_${_selected.length}.${_format.toLowerCase()}',
        size: '${(0.4 * _selected.length).toStringAsFixed(1)} MB',
        date: 'Just now',
        path: dir.path,
        icon: _format == 'PNG' ? Icons.image_outlined : Icons.photo_outlined,
        color: const Color(0xFF10B981),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selected.length} page(s) saved as $_format')),
      );
      _reset();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: Text(_pdfName == null ? 'PDF to Image' : 'Select (${_selected.length}/$_pdfPages)'),
        leading: _pdfName != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _reset) : null,
        actions: [
          if (_pdfName != null)
            TextButton(
              onPressed: _selectAll,
              child: Text(_selected.length == _pdfPages ? 'None' : 'All',
                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _rendering
        ? const Center(child: CircularProgressIndicator(color: kPrimary))
        : _pdfName == null ? _buildEmpty(isDark) : _buildPages(isDark),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: _openPicker,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimary.withOpacity(0.35), width: 2),
                ),
                child: const Icon(Icons.upload_file, size: 48, color: kPrimary),
              ),
            ),
            const SizedBox(height: 26),
            Text('Select PDF File',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _openPicker,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Select Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPages(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF111C33) : Colors.white,
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: kPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pdfName!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : kTextDark)),
                    Text('$_pdfPages pages · $_pdfSize',
                      style: const TextStyle(fontSize: 11, color: kTextLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pdfPages,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
            itemBuilder: (context, i) {
              final n = i + 1;
              final selected = _selected.contains(n);
              return InkWell(
                onTap: () => _toggleSelect(n),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? kPrimary : kBorder, width: selected ? 2.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Stack(
                            children: [
                              const Center(child: Icon(Icons.article_outlined, size: 32, color: Color(0x66000000))),
                              Positioned(
                                top: 4, right: 4,
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: selected ? kPrimary : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kPrimary, width: 1.5),
                                  ),
                                  child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Page $n',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : kTextMid)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111C33) : Colors.white,
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Format:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    _FormatChip(label: 'PNG', active: _format == 'PNG', onTap: () => setState(() => _format = 'PNG')),
                    const SizedBox(width: 8),
                    _FormatChip(label: 'JPG', active: _format == 'JPG', onTap: () => setState(() => _format = 'JPG')),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selected.isEmpty ? null : _download,
                    icon: const Icon(Icons.download_outlined),
                    label: Text('Download ${_selected.length} as $_format'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FormatChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kPrimary : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
          color: active ? Colors.white : kTextMid)),
      ),
    );
  }
}

// ═══ OCR ═══
class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});
  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  String? _source, _imagePath;
  bool _processing = false, _extracted = false;
  final List<OcrTextBox> _boxes = [];
  int _uid = 0;

  Future<void> _pick(String src) async {
    XFile? file = await ImagePicker().pickImage(
      source: src == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() {
      _source = src;
      _imagePath = file!.path;
      _processing = false;
      _extracted = false;
      _boxes.clear();
    });
  }

  Future<void> _extractText() async {
    if (_imagePath == null) return;
    setState(() => _processing = true);
    try {
      final input = InputImage.fromFilePath(_imagePath!);
      final recognizer = TextRecognizer();
      final result = await recognizer.processImage(input);
      setState(() {
        _processing = false;
        _extracted = true;
        _boxes.clear();
        for (final block in result.blocks) {
          final rect = block.boundingBox;
          if (rect == null) continue;
          _boxes.add(OcrTextBox(
            id: 'b${_uid++}',
            position: Offset(rect.left, rect.top),
            size: Size(rect.width, rect.height),
            text: block.text,
          ));
        }
      });
      await recognizer.close();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR failed: $e')));
      setState(() => _processing = false);
    }
  }

  void _editBox(OcrTextBox box) {
    final c = TextEditingController(text: box.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(controller: c, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => box.text = c.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _reset() => setState(() {
    _source = null;
    _imagePath = null;
    _processing = false;
    _extracted = false;
    _boxes.clear();
  });

  void _download(String fmt) {
    appState.addCreated(DocFile(
      name: 'Edited_${appState.createdFiles.length + 1}.${fmt.toLowerCase()}',
      size: '0.6 MB',
      date: 'Just now',
      path: _imagePath,
      icon: Icons.image_outlined,
      color: const Color(0xFFEF4444),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image with edited text saved as $fmt')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: const Text('Image Text Edit'),
        leading: _source != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _reset) : null,
      ),
      body: _source == null ? _buildPicker(isDark) : _buildEditor(isDark),
    );
  }

  Widget _buildPicker(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.text_fields, size: 46, color: kPrimary),
            ),
            const SizedBox(height: 24),
            Text('Extract Text from Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 30),
            _BigOption(icon: Icons.camera_alt_outlined, label: 'Camera',
              subtitle: 'Take a photo', color: kPrimary, onTap: () => _pick('camera')),
            const SizedBox(height: 12),
            _BigOption(icon: Icons.photo_library_outlined, label: 'Gallery',
              subtitle: 'Pick from photos', color: const Color(0xFF10B981), onTap: () => _pick('gallery')),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_imagePath != null)
                  AspectRatio(
                    aspectRatio: 0.75,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.file(File(_imagePath!), fit: BoxFit.contain,
                            width: double.infinity, height: double.infinity),
                          if (_extracted)
                            ..._boxes.map((b) => Positioned(
                              left: b.position.dx,
                              top: b.position.dy,
                              child: GestureDetector(
                                onTap: () => _editBox(b),
                                child: Container(
                                  width: b.size.width,
                                  height: b.size.height,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withOpacity(0.08),
                                    border: Border.all(color: kPrimary.withOpacity(0.6), width: 1.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(b.text,
                                    style: const TextStyle(fontSize: 11.5,
                                      color: Color(0xFF111827), fontWeight: FontWeight.w600),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            )),
                          if (_processing)
                            Container(
                              color: Colors.black.withOpacity(0.45),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 14),
                                    Text('Extracting...', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!_extracted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _extractText,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Edit Text'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_extracted)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111C33) : Colors.white,
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _download('PNG'),
                      child: const Text('Save PNG'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _download('JPG'),
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                      child: const Text('Save JPG'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BigOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _BigOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111C33) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kTextDark)),
                  Text(subtitle, style: TextStyle(fontSize: 11.5,
                    color: isDark ? const Color(0xFF7A8699) : kTextLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ MINI CANVA ═══
class MiniCanvaScreen extends StatefulWidget {
  const MiniCanvaScreen({super.key});
  @override
  State<MiniCanvaScreen> createState() => _MiniCanvaScreenState();
}

class _MiniCanvaScreenState extends State<MiniCanvaScreen> {
  PageSize? _size;
  double _customW = 210, _customH = 297;
  final List<CanvaElement> _elements = [];
  int _selected = -1, _uid = 0;
  Color _bgColor = Colors.white;
  String? _bgImagePath;

  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    if (_size == null) return _buildSizePicker(isDark);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() { _size = null; _elements.clear(); _selected = -1; }),
        ),
        title: Text(_size!.name),
      ),
      body: Column(
        children: [
          Expanded(child: _buildCanvas()),
          _buildToolbar(isDark),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: _customW / _customH,
          child: GestureDetector(
            onTap: () => setState(() => _selected = -1),
            child: Container(
              decoration: BoxDecoration(
                color: _bgImagePath != null ? null : _bgColor,
                image: _bgImagePath != null
                  ? DecorationImage(image: FileImage(File(_bgImagePath!)), fit: BoxFit.cover)
                  : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14)],
              ),
              child: ClipRect(
                child: Stack(
                  children: _elements.asMap().entries.map((e) => _buildElement(e.value, e.key)).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElement(CanvaElement el, int key) {
    final selected = key == _selected;
    Widget content = const SizedBox();
    if (el.type == 'text') {
      content = Center(
        child: Text(el.text ?? '',
          style: TextStyle(color: el.color, fontSize: el.fontSize)),
      );
    } else if (el.type == 'image' && el.imagePath != null) {
      content = Image.file(File(el.imagePath!), fit: BoxFit.cover);
    } else if (el.type == 'rect') {
      content = Container(color: el.color);
    } else if (el.type == 'circle') {
      content = Container(decoration: BoxDecoration(color: el.color, shape: BoxShape.circle));
    } else if (el.type == 'sticker') {
      content = Center(child: Text(el.emoji ?? '', style: TextStyle(fontSize: el.fontSize)));
    }
    return Positioned(
      left: el.position.dx,
      top: el.position.dy,
      child: GestureDetector(
        onTap: () => setState(() => _selected = key),
        onPanUpdate: (d) => setState(() { el.position += d.delta; _selected = key; }),
        child: Container(
          width: el.size.width,
          height: el.size.height,
          decoration: BoxDecoration(
            border: selected ? Border.all(color: kPrimary, width: 1.5) : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(child: content),
              if (selected)
                Positioned(
                  top: -30, right: -30,
                  child: GestureDetector(
                    onTap: () => setState(() { _elements.removeAt(key); _selected = -1; }),
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF111C33) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _CanvaBtn(icon: Icons.wallpaper, label: 'Background', onTap: _showBgPicker),
              _CanvaBtn(icon: Icons.text_fields, label: 'Text', onTap: _addText),
              _CanvaBtn(icon: Icons.image_outlined, label: 'Image', onTap: _addImage),
              _CanvaBtn(icon: Icons.crop_square, label: 'Square', onTap: () => _addShape('rect')),
              _CanvaBtn(icon: Icons.circle_outlined, label: 'Circle', onTap: () => _addShape('circle')),
              _CanvaBtn(icon: Icons.emoji_emotions_outlined, label: 'Sticker', onTap: _addSticker),
              _CanvaBtn(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: _selected >= 0 ? () => setState(() { _elements.removeAt(_selected); _selected = -1; }) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizePicker(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: const Text('Choose Page Size'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: kPageSizes.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => setState(() { _size = s; _customW = s.width; _customH = s.height; }),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111C33) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: kPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(s.icon, color: kPrimary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(s.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : kTextDark)),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  void _addText() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (c.text.trim().isEmpty) return;
              setState(() {
                _elements.add(CanvaElement(
                  id: 'e${_uid++}',
                  position: const Offset(70, 130),
                  size: const Size(200, 60),
                  type: 'text',
                  text: c.text,
                  color: Colors.black,
                  fontSize: 24,
                ));
                _selected = _elements.length - 1;
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    setState(() {
      _elements.add(CanvaElement(
        id: 'e${_uid++}',
        position: const Offset(80, 120),
        size: const Size(180, 140),
        type: 'image',
        imagePath: f.path,
      ));
      _selected = _elements.length - 1;
    });
  }

  void _addShape(String type) {
    setState(() {
      _elements.add(CanvaElement(
        id: 'e${_uid++}',
        position: const Offset(100, 140),
        size: const Size(110, 110),
        type: type,
        color: kPrimary,
      ));
      _selected = _elements.length - 1;
    });
  }

  void _addSticker() {
    setState(() {
      _elements.add(CanvaElement(
        id: 'e${_uid++}',
        position: const Offset(130, 160),
        size: const Size(70, 70),
        type: 'sticker',
        emoji: '⭐',
        fontSize: 48,
      ));
      _selected = _elements.length - 1;
    });
  }

  Future<void> _showBgPicker() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() => _bgImagePath = f.path);
  }
}

class _CanvaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _CanvaBtn({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = disabled ? const Color(0xFFBFC7D5) : kTextMid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══ ENHANCER ═══
class EnhancerScreen extends StatefulWidget {
  const EnhancerScreen({super.key});
  @override
  State<EnhancerScreen> createState() => _EnhancerScreenState();
}

class _EnhancerScreenState extends State<EnhancerScreen> {
  double _deskew = 0, _contrast = 1.0, _brightness = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: const Text('Document Enhancer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Page Straightening', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kTextDark)),
          Slider(
            value: _deskew, min: -15, max: 15, divisions: 60,
            label: '${_deskew.toStringAsFixed(1)}°',
            onChanged: (v) => setState(() => _deskew = v),
            activeColor: kPrimary,
          ),
          Text('Contrast', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kTextDark)),
          Slider(
            value: _contrast, min: 0.5, max: 2.0, divisions: 30,
            onChanged: (v) => setState(() => _contrast = v),
            activeColor: kPrimary,
          ),
          Text('Brightness', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kTextDark)),
          Slider(
            value: _brightness, min: 0.5, max: 2.0, divisions: 30,
            onChanged: (v) => setState(() => _brightness = v),
            activeColor: kPrimary,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () {
              appState.addCreated(DocFile(
                name: 'Enhanced_${appState.createdFiles.length + 1}.jpg',
                size: '1.8 MB',
                date: 'Just now',
                icon: Icons.auto_fix_high_outlined,
                color: const Color(0xFF6366F1),
              ));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
            },
          ),
        ],
      ),
    );
  }
}

// ═══ SCANNER ═══
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});
  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: const Text('Document Scanner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
            child: const Center(child: Text('Camera preview', style: TextStyle(color: Colors.white70))),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Start Scanning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
                if (f == null) return;
                appState.addCreated(DocFile(
                  name: 'Scan_${appState.createdFiles.length + 1}.pdf',
                  size: '1.5 MB',
                  date: 'Just now',
                  path: f.path,
                  icon: Icons.document_scanner_outlined,
                  color: const Color(0xFF2563EB),
                ));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image captured')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ GENERIC ═══
class GenericToolScreen extends StatelessWidget {
  final Tool tool;
  const GenericToolScreen({super.key, required this.tool});
  @override
  Widget build(BuildContext context) {
    final isDark = appState.darkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : kBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111C33) : Colors.white,
        elevation: 0,
        title: Text(tool.label),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: tool.color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Icon(tool.icon, size: 52, color: tool.color),
                const SizedBox(height: 12),
                Text(tool.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : kTextDark)),
                const SizedBox(height: 6),
                Text(tool.description, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5,
                    color: isDark ? const Color(0xFFCBD5E1) : kTextMid)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(tool.icon),
              label: Text('Select Files & ${tool.label.split(' ').first}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tool.color, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                appState.addCreated(DocFile(
                  name: '${tool.id}_${appState.createdFiles.length + 1}.pdf',
                  size: '1.2 MB',
                  date: 'Just now',
                  icon: tool.icon,
                  color: tool.color,
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}