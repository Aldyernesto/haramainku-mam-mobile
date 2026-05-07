import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'project_detail_screen.dart';
import 'uploads_screen.dart';
import 'qr_scanner_screen.dart';
import 'global_chat_screen.dart';
import 'settings_screen.dart';

const _getProjects = '''
  query GetProjects {
    projects { id title description totalFiles totalSize coverImage createdAt }
  }
''';

const _createProject = '''
  mutation CreateProject(\$input: CreateProjectInput!) {
    createProject(input: \$input) { id title }
  }
''';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();

  Future<void> _doCreate(BuildContext context, VoidCallback? refetch) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final client = GraphQLProvider.of(context).value;
    await client.mutate(MutationOptions(
      document: gql(_createProject),
      variables: {'input': {'title': title, 'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(), 'coverImage': _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim()}},
    ));
    _titleCtrl.clear(); _descCtrl.clear(); _coverCtrl.clear();
    refetch?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Query(
      options: QueryOptions(document: gql(_getProjects), pollInterval: const Duration(seconds: 30)),
      builder: (result, {refetch, fetchMore}) {
        final projects = (result.data?['projects'] as List<dynamic>?) ?? [];
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3),
            title: const Text('MEDIA'),
            actions: [
              IconButton(icon: const Icon(Icons.search, color: AppTheme.gold), onPressed: () => showSearch(context: context, delegate: _ProjectSearch(projects))),
              if (user.canUpload)
                IconButton(icon: const Icon(Icons.add_box_outlined, color: AppTheme.gold), onPressed: () => _showCreateDialog(context, refetch)),
              IconButton(icon: const Icon(Icons.qr_code_scanner, color: AppTheme.gold), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen()))),
            ],
          ),
          body: Container(
            color: AppTheme.surface,
            child: projects.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.folder_open, size: 64, color: AppTheme.gold.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No projects yet', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (user.canUpload) ElevatedButton.icon(onPressed: () => _showCreateDialog(context, refetch), icon: const Icon(Icons.add), label: const Text('Create Project')),
                  ]))
                : RefreshIndicator(
                    onRefresh: () async => refetch?.call(),
                    color: AppTheme.gold,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
                      itemCount: projects.length,
                      itemBuilder: (_, i) => _NetflixCard(project: projects[i]),
                    ),
                  ),
          ),
          bottomNavigationBar: _bottomNav(context, user),
        );
      },
    );
  }

  Widget _buildCoverPreview(String pathOrUrl) {
    final isUrl = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
    return Image(
      image: isUrl ? NetworkImage(pathOrUrl) : FileImage(File(pathOrUrl)) as ImageProvider,
      width: 48, height: 48, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(),
    );
  }

  void _showCreateDialog(BuildContext context, VoidCallback? refetch) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('New Project', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
          const SizedBox(height: 20),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Haji 2026'), style: const TextStyle(color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), style: const TextStyle(color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          Row(children: [
            if (_coverCtrl.text.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildCoverPreview(_coverCtrl.text))
            else
              Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.gold.withValues(alpha: 0.1)), child: const Icon(Icons.image, color: AppTheme.gold)),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
              if (img == null) return;
              final token = await context.read<AuthProvider>().token;
              if (token == null) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated')));
                return;
              }
              try {
                final uri = Uri.parse('https://mam.haramaintour.com/api/upload/cover');
                final req = http.MultipartRequest('POST', uri)
                  ..headers['Authorization'] = 'Bearer $token'
                  ..files.add(await http.MultipartFile.fromPath('file', img.path));
                final res = await req.send();
                if (res.statusCode == 200) {
                  final body = await res.stream.bytesToString();
                  final url = (jsonDecode(body) as Map)['url'] as String;
                  setState(() => _coverCtrl.text = url);
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover upload failed')));
                }
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover upload failed')));
              }
            }, icon: const Icon(Icons.image, size: 16), label: const Text('Pick Cover')),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { _doCreate(context, refetch); }, child: const Text('Create'))),
        ]),
      ),
    );
  }

  Widget _bottomNav(BuildContext context, dynamic user) => Container(
    decoration: BoxDecoration(color: AppTheme.surfaceContainerHighest, border: Border(top: BorderSide(color: AppTheme.blueAccent.withValues(alpha: 0.2)))),
    child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _NavItem(icon: Icons.grid_view_rounded, label: 'Projects', active: true, onTap: () {}),
        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalChatScreen())),
          child: const _NavItem(icon: Icons.chat_bubble_outline, label: 'Chat', active: false)),
        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), child: const _NavItem(icon: Icons.person_outline, label: 'Profile', active: false)),
      ]),
    )),
  );
}

class _NetflixCard extends StatelessWidget {
  final dynamic project;
  const _NetflixCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final coverRaw = project['coverImage'] as String?;
    final hasCover = coverRaw != null && coverRaw.isNotEmpty;
    final isNetworkCover = hasCover && (coverRaw!.startsWith('http://') || coverRaw.startsWith('https://'));
    final coverProvider = hasCover
        ? (isNetworkCover ? NetworkImage(coverRaw!) : FileImage(File(coverRaw!)) as ImageProvider)
        : null;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: project['id'], projectTitle: project['title']),
      )),
      child: Container(
        height: 220, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: AppTheme.surfaceContainer,
          image: coverProvider != null ? DecorationImage(image: coverProvider, fit: BoxFit.cover) : null,
          boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppTheme.surface.withValues(alpha: 0.7), AppTheme.surface], stops: const [0.3, 0.7, 1.0]),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppTheme.gold.withValues(alpha: 0.2)),
              child: const Text('PROJECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.gold, letterSpacing: 1.5))),
            const SizedBox(height: 8),
            Text(project['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.onSurface, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.folder, size: 14, color: AppTheme.gold.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text('${project['totalFiles'] ?? 0} files', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              const SizedBox(width: 16),
              Icon(Icons.storage, size: 14, color: AppTheme.gold.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(_fmt(project['totalSize'] ?? 0), style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _fmt(dynamic s) {
    final b = int.tryParse(s?.toString() ?? '0') ?? 0;
    if (b < 1048576) return '${(b/1024).toStringAsFixed(0)}KB';
    if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)}MB';
    return '${(b/1073741824).toStringAsFixed(1)}GB';
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback? onTap;
  const _NavItem({required this.icon, required this.label, required this.active, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: active ? AppTheme.gold : AppTheme.onSurfaceVariant, size: 22),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, color: active ? AppTheme.gold : AppTheme.onSurfaceVariant)),
    ]),
  );
}

void _showProfile(BuildContext context, dynamic user) {
  final auth = context.read<AuthProvider>();
  showModalBottomSheet(context: context, backgroundColor: AppTheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.gold.withValues(alpha: 0.1)), child: const Icon(Icons.person, size: 32, color: AppTheme.gold)),
        const SizedBox(height: 12),
        Text(user?.email ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3))),
          child: Text(user?.roleLabel ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.gold))),
        const SizedBox(height: 24),
        ListTile(leading: const Icon(Icons.logout, color: AppTheme.onSurfaceVariant), title: const Text('Logout'), onTap: () { Navigator.pop(context); auth.logout(); Navigator.pushReplacementNamed(context, '/'); }),
      ]),
    )),
  );
}

const _searchAll = '''
  query SearchAll(\$query: String!) {
    searchFiles(query: \$query) { id originalName mimeType size project { id title } folder { id name } }
    searchFolders(query: \$query) { id name project { id title } }
  }
''';

class _ProjectSearch extends SearchDelegate<String> {
  final List<dynamic> projects;
  _ProjectSearch(this.projects);
  @override List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear, color: AppTheme.gold), onPressed: () => query = '')];
  @override Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold), onPressed: () => close(context, ''));
  @override Widget buildResults(BuildContext context) => _list(context);
  @override Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    if (query.isEmpty) {
      // Show all projects when empty
      final r = projects;
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: r.length, itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.folder, color: AppTheme.gold), title: Text(r[i]['title'], style: const TextStyle(color: AppTheme.onSurface)),
        subtitle: Text('${r[i]['totalFiles']} files', style: const TextStyle(color: AppTheme.onSurfaceVariant)),
        onTap: () { close(context, r[i]['id']); Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: r[i]['id'], projectTitle: r[i]['title']))); },
      ));
    }
    // Real GraphQL search for non-empty queries
    return Query(
      options: QueryOptions(document: gql(_searchAll), variables: {'query': query}),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
        final files = (result.data?['searchFiles'] as List<dynamic>?) ?? [];
        final folders = (result.data?['searchFolders'] as List<dynamic>?) ?? [];
        // Filter projects locally (backend doesn't support search filter for projects)
        final filteredProjects = projects.where((p) => (p['title'] as String).toLowerCase().contains(query.toLowerCase())).toList();
        if (files.isEmpty && folders.isEmpty && filteredProjects.isEmpty) {
          return const Center(child: Text('No results found', style: TextStyle(color: AppTheme.onSurfaceVariant)));
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (filteredProjects.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('PROJECTS', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant, letterSpacing: 1))),
            ...filteredProjects.map((p) => ListTile(
              leading: const Icon(Icons.folder_special, color: AppTheme.gold, size: 22),
              title: Text(p['title'] ?? '', style: const TextStyle(color: AppTheme.onSurface)),
              subtitle: Text('${p['totalFiles']} files', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              onTap: () { close(context, p['id']); Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p['id'], projectTitle: p['title']))); },
            )),
          ],
          if (folders.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('FOLDERS', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant, letterSpacing: 1))),
            ...folders.map((f) => ListTile(
              leading: const Icon(Icons.folder, color: AppTheme.gold, size: 22),
              title: Text(f['name'] ?? '', style: const TextStyle(color: AppTheme.onSurface)),
              subtitle: Text(f['project']?['title'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              onTap: () { close(context, f['id']); Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: f['id'], projectTitle: f['name'], isFolder: true))); },
            )),
          ],
          if (files.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(top: 8, bottom: 8), child: Text('FILES', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant, letterSpacing: 1))),
            ...files.map((f) => ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppTheme.gold, size: 22),
              title: Text(f['originalName'] ?? '', style: const TextStyle(color: AppTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${f['project']?['title'] ?? ''} ${f['folder']?['name'] != null ? '/ ${f['folder']['name']}' : ''}  •  ${_searchFmt(f['size'] ?? 0)}', style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
              onTap: () { close(context, f['project']?['id'] ?? ''); Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: f['folder']?['id'] ?? f['project']?['id'] ?? '', projectTitle: f['project']?['title'] ?? '', isFolder: f['folder']?['id'] != null))); },
            )),
          ],
        ]);
      },
    );
  }

  static String _searchFmt(dynamic s) { final b = int.tryParse(s?.toString() ?? '0') ?? 0; if (b < 1048576) return '${(b/1024).toStringAsFixed(0)} KB'; if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB'; return '${(b/1073741824).toStringAsFixed(1)} GB'; }
}
