import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/background_upload.dart';
import 'chat_screen.dart';

class _ChunkData {
  final int index;
  final List<int> bytes;
  const _ChunkData({required this.index, required this.bytes});
}

class _FileToUpload {
  final String path;
  final String name;
  final int size;
  const _FileToUpload({required this.path, required this.name, required this.size});
}

enum _UpStatus { pending, uploading, done, error }

class _UploadingFile {
  final String name;
  _UpStatus status;
  double percent;
  String? error;
  _UploadingFile({required this.name, this.status = _UpStatus.pending, this.percent = 0.0, this.error});
}

const _getProject = '''query GetProject(\$id: ID!) { project(id: \$id) { id title description totalFiles totalSize folders { id name totalFiles createdAt } } }''';
const _getFolder = '''query GetFolder(\$id: ID!) { folder(id: \$id) { id name totalFiles folderType project { id title } parent { id name } children { id name totalFiles createdAt } files { id originalName mimeType size createdAt thumbnailPath } } }''';
const _pickerProject = '''query PickerProject(\$id: ID!) { project(id: \$id) { id title folders { id name } } }''';
const _pickerFolder = '''query PickerFolder(\$id: ID!) { folder(id: \$id) { id name project { id title } parent { id name } children { id name } } }''';
const _moveToTrash = '''mutation MoveToTrash(\$fileId: ID!) { moveToTrash(fileId: \$fileId) }''';
const _moveFolderToTrash = '''mutation MoveFolderToTrash(\$folderId: ID!) { moveFolderToTrash(folderId: \$folderId) }''';
const _moveFile = '''mutation MoveFile(\$fileId: ID!, \$targetFolderId: ID!) { moveFile(fileId: \$fileId, targetFolderId: \$targetFolderId) { id } }''';
const _moveFolder = '''mutation MoveFolder(\$folderId: ID!, \$targetFolderId: ID!) { moveFolder(folderId: \$folderId, targetFolderId: \$targetFolderId) { id } }''';
const _createShare = '''mutation CreateShareLink(\$input: ShareLinkInput!) { createShareLink(input: \$input) { url } }''';
const _createFolderShare = '''mutation CreateShareLink(\$input: ShareLinkInput!) { createShareLink(input: \$input) { url } }''';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final bool isFolder;
  const ProjectDetailScreen({super.key, required this.projectId, required this.projectTitle, this.isFolder = false});
  @override State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _selFiles = <String>{};
  final _selFolders = <String>{};
  bool _selMode = false;

  @override Widget build(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    final query = widget.isFolder ? _getFolder : _getProject;
    final dataKey = widget.isFolder ? 'folder' : 'project';

    return Query(
      options: QueryOptions(document: gql(query), variables: {'id': widget.projectId}),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading) return Scaffold(appBar: _bar(), body: const Center(child: CircularProgressIndicator(color: AppTheme.gold)));
        if (result.hasException) return Scaffold(appBar: _bar(), body: Center(child: Text('Error: ${result.exception}', style: const TextStyle(color: Colors.redAccent))));
        final data = result.data?[dataKey];
        if (data == null) return Scaffold(appBar: _bar(), body: const Center(child: Text('Not found', style: TextStyle(fontSize: 16, color: AppTheme.onSurfaceVariant))));

        final title = data['name'] ?? data['title'] ?? widget.projectTitle;
        final folders = (data['children'] ?? data['folders'] as List<dynamic>?) ?? [];
        final files = (data['files'] as List<dynamic>?) ?? [];
        final totalFiles = data['totalFiles'] ?? files.length;
        final realProjectId = widget.isFolder ? (data['project']?['id'] as String?) : widget.projectId;
        final folderType = widget.isFolder ? (data['folderType'] as String?) : null;

        // BUILD MARKER v7 — select-all + deselect-all toggle
    return PopScope(
          canPop: !_selMode,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _selMode) {
              setState(() { _selFiles.clear(); _selFolders.clear(); _selMode = false; });
            }
          },
          child: Scaffold(
          extendBodyBehindAppBar: !_selMode,
          appBar: _selMode ? _selBar(title, folders, files) : _bar(title: title, client: client),
          body: Stack(children: [Container(color: AppTheme.surface, child: CustomScrollView(slivers: [
            if (!_selMode) SliverAppBar(expandedHeight: 160, pinned: true, backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3), automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.gold)),
                background: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.surfaceContainerHigh, AppTheme.surface.withValues(alpha: 0.8)])),
                  child: Center(child: Icon(widget.isFolder ? Icons.folder : Icons.folder_special, size: 64, color: AppTheme.gold.withValues(alpha: 0.3))))),
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatChip(label: '$totalFiles', sub: 'Files'), _StatChip(label: '${folders.length}', sub: 'Folders'),
              ]),
            )),
            if (!_selMode && folders.isNotEmpty) ...[
              SliverToBoxAdapter(child: _sectionHeader('Folders')),
              SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverGrid(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
                delegate: SliverChildBuilderDelegate((_, i) => _FolderTile(
                  folder: folders[i], selMode: false, selected: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: folders[i]['id'], projectTitle: folders[i]['name'], isFolder: true))),
                  onLongPress: () => _enterSelectFolder(folders[i]['id']),
                ), childCount: folders.length)),
              ),
            ],
            if (!_selMode && files.isNotEmpty) ...[
              SliverToBoxAdapter(child: _sectionHeader('Files')),
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => _FileTile(
                file: files[i], selMode: false, selected: false,
                onTap: () => _showPreview(context, files[i], client),
                onLongPress: () => _enterSelectFile(files[i]['id']),
              ), childCount: files.length)),
              ),
            ],
            if (_selMode) ...[
              if (folders.isNotEmpty) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverGrid(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
                delegate: SliverChildBuilderDelegate((_, i) => _FolderTile(
                  folder: folders[i], selMode: true, selected: _selFolders.contains(folders[i]['id']),
                  onTap: () => _toggleFolder(folders[i]['id']),
                  onLongPress: () => _toggleFolder(folders[i]['id']),
                ), childCount: folders.length)),
              ),
              if (files.isNotEmpty) SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => _FileTile(
                file: files[i], selMode: true, selected: _selFiles.contains(files[i]['id']),
                onTap: () => _toggleFile(files[i]['id']),
                onLongPress: () => _toggleFile(files[i]['id']),
              ), childCount: files.length)),
              ),
            ],
          ])),
            if (_hasSelection) Positioned(left: 0, right: 0, bottom: 0, child: _bulkBar(client, folders, refetch, realProjectId)),
          ]),
          floatingActionButton: (!_selMode && widget.isFolder) ? FloatingActionButton(onPressed: () => _showFabMenu(context, client, title, refetch, realProjectId, folderType), backgroundColor: AppTheme.gold, child: const Icon(Icons.add, color: Color(0xFF1e1c00))) : null,
        ),
        );
      },
    );
  }

  bool get _hasSelection => _selFiles.isNotEmpty || _selFolders.isNotEmpty;
  void _toggleFile(String id) => setState(() => _selFiles.contains(id) ? _selFiles.remove(id) : _selFiles.add(id));
  void _toggleFolder(String id) => setState(() => _selFolders.contains(id) ? _selFolders.remove(id) : _selFolders.add(id));
  void _enterSelectFile(String id) => setState(() { _selMode = true; _selFiles.add(id); });
  void _enterSelectFolder(String id) => setState(() { _selMode = true; _selFolders.add(id); });

  Future<void> _pickAndUpload(BuildContext context, GraphQLClient client, String folderName, VoidCallback? refetch, String? realProjectId, [String? folderType]) async {
    final accept = _acceptForFolder(folderType ?? folderName);
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: accept != null ? FileType.custom : FileType.any, allowedExtensions: accept);
    if (result == null || result.files.isEmpty) return;
    final files = result.files.where((f) => f.path != null).map((f) => _FileToUpload(path: f.path!, name: f.name, size: f.size)).toList();
    if (files.isEmpty) return;
    await _doUpload(context, client, files, refetch, realProjectId);
  }

  Future<void> _pickFromGallery(BuildContext context, GraphQLClient client, String folderName, VoidCallback? refetch, String? realProjectId, [String? folderType]) async {
    final isVideo = (folderType ?? folderName).toLowerCase() == 'video';
    final isPhoto = (folderType ?? folderName).toLowerCase() == 'photo';
    final reqType = isVideo ? RequestType.video : (isPhoto ? RequestType.image : RequestType.common);

    final picked = await AssetPicker.pickAssets(context, pickerConfig: AssetPickerConfig(requestType: reqType, maxAssets: 50));
    if (picked == null || picked.isEmpty) return;

    final files = <_FileToUpload>[];
    for (final entity in picked) {
      final file = await entity.file;
      if (file == null) continue;
      files.add(_FileToUpload(path: file.path, name: entity.title ?? file.path.split('/').last, size: await file.length()));
    }
    if (files.isEmpty) return;
    if (!context.mounted) return;
    await _doUpload(context, client, files, refetch, realProjectId);
  }

  Future<void> _doUpload(BuildContext context, GraphQLClient client, List<_FileToUpload> files, VoidCallback? refetch, String? realProjectId) async {
    if (!context.mounted) return;

    final fileStates = <_UploadingFile>[];
    for (final f in files) {
      fileStates.add(_UploadingFile(name: f.name, status: _UpStatus.pending, percent: 0.0));
    }
    bool _showAll = files.length <= 3;
    StateSetter? _sheetSetState;

    // Show upload bottom sheet
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          _sheetSetState = setState;
          final displayFiles = _showAll ? fileStates : [...fileStates.take(3)];
          final hasErrors = fileStates.any((s) => s.status == _UpStatus.error);
          final allDone = fileStates.every((s) => s.status == _UpStatus.done || s.status == _UpStatus.error);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: Text(
                      hasErrors ? 'Upload Complete (with errors)' : allDone ? '${fileStates.where((s) => s.status == _UpStatus.done).length} Files Uploaded' : 'Uploading ${fileStates.where((s) => s.status != _UpStatus.done).length} of ${files.length}',
                      style: TextStyle(color: hasErrors ? Colors.redAccent : AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                    )),
                    if (allDone)
                      IconButton(onPressed: () { Navigator.pop(ctx); if (mounted) refetch?.call(); }, icon: const Icon(Icons.close, color: AppTheme.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 12),
                  ...List.generate(displayFiles.length, (i) {
                    final s = displayFiles[i];
                    final isActive = s.status == _UpStatus.uploading;
                    final isDone = s.status == _UpStatus.done;
                    final isErr = s.status == _UpStatus.error;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.gold.withValues(alpha: 0.08) : AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: isActive ? Border.all(color: AppTheme.gold.withValues(alpha: 0.3)) : null,
                      ),
                      child: Row(children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isDone ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22)
                              : isErr ? const Icon(Icons.error, color: Colors.redAccent, size: 22)
                              : s.status == _UpStatus.pending ? const Icon(Icons.hourglass_empty, color: AppTheme.onSurfaceVariant, size: 22)
                              : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.gold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: TextStyle(color: isDone ? AppTheme.onSurfaceVariant : AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: s.percent,
                                minHeight: 4,
                                color: isErr ? Colors.redAccent : isDone ? const Color(0xFF4CAF50) : AppTheme.gold,
                                backgroundColor: AppTheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isErr ? (s.error ?? 'Failed') : isDone ? '100% · Complete' : s.status == _UpStatus.pending ? 'Waiting...' : '${(s.percent * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: isErr ? Colors.redAccent : AppTheme.onSurfaceVariant, fontSize: 11),
                            ),
                          ]),
                        ),
                      ]),
                    );
                  }),
                  if (files.length > 3)
                    GestureDetector(
                      onTap: () => setState(() => _showAll = !_showAll),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_showAll ? Icons.expand_less : Icons.expand_more, color: AppTheme.gold, size: 18),
                          const SizedBox(width: 4),
                          Text(_showAll ? 'Show less' : 'Show all (${files.length} files)', style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  if (allDone || hasErrors)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(width: double.infinity, child: ElevatedButton(
                        onPressed: () { Navigator.pop(ctx); if (mounted) refetch?.call(); },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: const Color(0xFF141310), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                      )),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Run upload loop
    for (int fi = 0; fi < files.length; fi++) {
      final f = files[fi];
      final st = fileStates[fi];
      st.status = _UpStatus.uploading;
      _sheetSetState?.call(() {});

      try {
        // 1. Latency check
        final pingStart = DateTime.now().millisecondsSinceEpoch;
        try { await http.get(Uri.parse('https://mam.haramaintour.com/api/ping')).timeout(const Duration(seconds: 3)); } catch (_) {}
        final latencyMs = DateTime.now().millisecondsSinceEpoch - pingStart;

        // 2. Initiate upload via GraphQL
        final initRes = await client.mutate(MutationOptions(
          document: gql('''mutation InitiateUpload(\$input: InitiateUploadInput!) { initiateUpload(input: \$input) { id chunkSize totalChunks uploadMode presignedUrl r2Key } }'''),
          variables: {'input': {'filename': f.name, 'totalSize': f.size, 'projectId': realProjectId ?? widget.projectId, 'folderId': widget.isFolder ? widget.projectId : null, 'clientLatencyMs': latencyMs}},
        ));
        final sessionId = initRes.data?['initiateUpload']?['id'];
        if (sessionId == null) throw Exception('Failed to initiate');

        final uploadMode = initRes.data?['initiateUpload']?['uploadMode'] ?? 'direct';
        final presignedUrl = initRes.data?['initiateUpload']?['presignedUrl'];
        final r2Key = initRes.data?['initiateUpload']?['r2Key'];
        final token = await const FlutterSecureStorage().read(key: 'auth_token') ?? '';
        final cs = (initRes.data?['initiateUpload']?['chunkSize'] as int?) ?? 52428800;
        final totalChunks = uploadMode == 'r2' ? 1 : ((initRes.data?['initiateUpload']?['totalChunks'] as int?) ?? 1);

        // Register background task in case app is killed mid-upload
        try {
          registerBackgroundUpload(
            filePath: f.path,
            fileName: f.name,
            sessionId: sessionId,
            token: token,
            mode: uploadMode,
            presignedUrl: presignedUrl,
            r2Key: r2Key,
            baseUrl: 'https://mam.haramaintour.com',
            chunkSize: cs,
            totalChunks: totalChunks,
          );
        } catch (_) {}

        // ---------- R2 MODE (streaming) ----------
        if (uploadMode == 'r2' && presignedUrl != null) {
          int retries = 0;
          while (retries < 3) {
            try {
              st.percent = 0.1; _sheetSetState?.call(() {});
              final file = File(f.path);
              final fileSize = await file.length();
              final request = http.StreamedRequest('PUT', Uri.parse(presignedUrl));
              request.headers['Content-Type'] = 'application/octet-stream';
              request.headers['Content-Length'] = fileSize.toString();
              final sink = request.sink;
              await for (final chunk in file.openRead()) {
                sink.add(chunk);
              }
              await sink.close();
              st.percent = 0.8; _sheetSetState?.call(() {});
              final streamedRes = await request.send().timeout(const Duration(seconds: 300));
              await streamedRes.stream.drain();
              if (streamedRes.statusCode == 200) break;
              retries++;
              if (retries >= 3) throw Exception('R2 upload failed: ${streamedRes.statusCode}');
              await Future.delayed(Duration(seconds: retries * 3));
            } catch (e) {
              retries++;
              if (retries >= 3) rethrow;
              await Future.delayed(Duration(seconds: retries * 3));
            }
          }
          await client.mutate(MutationOptions(
            document: gql('''mutation CompleteR2Upload(\$sessionId: ID!, \$r2Key: String!) { completeUpload(sessionId: \$sessionId, r2Key: \$r2Key) { id filename } }'''),
            variables: {'sessionId': sessionId, 'r2Key': r2Key},
          ));
          st.percent = 1.0;
          st.status = _UpStatus.done;
          _sheetSetState?.call(() {});
          continue;
        }

        // ---------- DIRECT MODE: chunked multipart ----------
        final raf = await File(f.path).open(mode: FileMode.read);
        final httpClient = http.Client();
        const maxParallel = 4;
        try {
          int i = 0;
          while (i < totalChunks) {
            final batch = <_ChunkData>[];
            while (batch.length < maxParallel && i < totalChunks) {
              final start = i * cs;
              final length = (start + cs > f.size) ? (f.size - start) : cs;
              await raf.setPosition(start);
              batch.add(_ChunkData(index: i, bytes: await raf.read(length)));
              i++;
            }
            await Future.wait(batch.map((c) async {
              int retries = 0;
              while (retries < 3) {
                try {
                  final mpReq = http.MultipartRequest('POST', Uri.parse('https://mam.haramaintour.com/api/upload/chunk'));
                  mpReq.headers['Authorization'] = 'Bearer $token';
                  mpReq.fields['sessionId'] = sessionId;
                  mpReq.fields['chunkIndex'] = c.index.toString();
                  mpReq.files.add(http.MultipartFile.fromBytes('file', c.bytes, filename: 'chunk'));
                  final streamedRes = await httpClient.send(mpReq).timeout(const Duration(seconds: 120));
                  final respBody = await streamedRes.stream.bytesToString();
                  if (streamedRes.statusCode != 200) {
                    throw Exception('Chunk ${c.index} HTTP ${streamedRes.statusCode}: ${respBody.length > 200 ? respBody.substring(0, 200) : respBody}');
                  }
                  return;
                } catch (_) {
                  retries++;
                  if (retries >= 3) rethrow;
                  await Future.delayed(Duration(seconds: retries * 2));
                }
              }
            }));
            st.percent = i / totalChunks;
            _sheetSetState?.call(() {});
          }
        } finally {
          await raf.close();
          httpClient.close();
        }

        await client.mutate(MutationOptions(
          document: gql('''mutation CompleteUpload(\$sessionId: ID!) { completeUpload(sessionId: \$sessionId) { id filename } }'''),
          variables: {'sessionId': sessionId},
        ));
        st.percent = 1.0;
        st.status = _UpStatus.done;
        _sheetSetState?.call(() {});
      } catch (e) {
        st.status = _UpStatus.error;
        st.error = e.toString();
        _sheetSetState?.call(() {});
      }
    }
  }

  void _showFabMenu(BuildContext ctx, GraphQLClient client, String folderName, VoidCallback? refetch, String? realProjectId, String? folderType) {
    showModalBottomSheet(context: ctx, backgroundColor: AppTheme.surfaceContainerHigh, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library, color: AppTheme.gold), title: const Text('Pick from Gallery', style: TextStyle(color: AppTheme.onSurface)), onTap: () { Navigator.pop(ctx); _pickFromGallery(ctx, client, folderName, refetch, realProjectId, folderType); }),
        ListTile(leading: const Icon(Icons.upload_file, color: AppTheme.gold), title: const Text('Upload Files', style: TextStyle(color: AppTheme.onSurface)), onTap: () { Navigator.pop(ctx); _pickAndUpload(ctx, client, folderName, refetch, realProjectId, folderType); }),
        ListTile(leading: const Icon(Icons.create_new_folder, color: AppTheme.gold), title: const Text('Create Folder', style: TextStyle(color: AppTheme.onSurface)), onTap: () { Navigator.pop(ctx); _showCreateFolderDialog(ctx, client, refetch, realProjectId); }),
      ]))),
    );
  }

  void _showCreateFolderDialog(BuildContext ctx, GraphQLClient client, VoidCallback? refetch, String? projectId) {
    final _ctrl = TextEditingController();
    showDialog(context: ctx, builder: (c) => AlertDialog(backgroundColor: AppTheme.surfaceContainerHigh, title: const Text('New Folder', style: TextStyle(color: AppTheme.onSurface)),
      content: TextField(controller: _ctrl, autofocus: true, style: const TextStyle(color: AppTheme.onSurface), decoration: const InputDecoration(hintText: 'Folder name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          Navigator.pop(c);
          if (_ctrl.text.trim().isEmpty || projectId == null) return;
          await client.mutate(MutationOptions(document: gql('''mutation CreateFolder(\$projectId: ID!, \$name: String!, \$parentId: ID) { createFolder(projectId: \$projectId, name: \$name, parentId: \$parentId) { id name } }'''), variables: {'projectId': projectId, 'name': _ctrl.text.trim(), 'parentId': widget.isFolder ? widget.projectId : null}));
          refetch?.call();
        }, child: const Text('Create', style: TextStyle(color: AppTheme.gold))),
      ],
    ));
  }

  List<String>? _acceptForFolder(String name) {
    final n = name.toLowerCase();
    if (n == 'video') return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', 'wmv', 'flv'];
    if (n == 'photo') return ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp', 'tiff', 'tif', 'dng', 'raw', 'cr2', 'nef', 'arw', 'orf', 'rw2'];
    return null;
  }

  AppBar _bar({String? title, GraphQLClient? client}) => AppBar(
    backgroundColor: AppTheme.navyGlass.withValues(alpha: 0.3),
    leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold), onPressed: () => Navigator.pop(context)),
    title: Text(title ?? 'MEDIA'),
    actions: [
      if (client != null) IconButton(icon: const Icon(Icons.share, color: AppTheme.gold), onPressed: () async {
        final res = await client.mutate(MutationOptions(document: gql(_createFolderShare), variables: {'input': {widget.isFolder ? 'folderId' : 'projectId': widget.projectId, 'mode': 'PUBLIC'}}));
        final link = res.data?['createShareLink']?['url'];
        if (link != null && context.mounted) {
          showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AppTheme.surfaceContainerHigh, title: const Text('Share Link', style: TextStyle(color: AppTheme.onSurface)), content: Text('$link', style: const TextStyle(fontSize: 12, color: AppTheme.gold)), actions: [
            TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: '$link')); Navigator.pop(context); }, child: const Text('Copy')),
          ]));
        }
      }),
    ],
  );

  AppBar _selBar(String title, List<dynamic> folders, List<dynamic> files) {
    final allFolderIds = folders.map((f) => f['id'] as String).toSet();
    final allFileIds = files.map((f) => f['id'] as String).toSet();
    final allSelected = _selFolders.containsAll(allFolderIds) && _selFiles.containsAll(allFileIds);
    return AppBar(
      backgroundColor: AppTheme.surfaceContainerHighest,
      leading: IconButton(icon: const Icon(Icons.close, color: AppTheme.gold), onPressed: () => setState(() { _selFiles.clear(); _selFolders.clear(); _selMode = false; })),
      title: Text('${_selFiles.length + _selFolders.length} selected'),
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all, color: AppTheme.gold),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          onPressed: () => setState(() {
            if (allSelected) {
              _selFolders.clear();
              _selFiles.clear();
            } else {
              _selFolders.addAll(allFolderIds);
              _selFiles.addAll(allFileIds);
            }
          }),
        ),
      ],
    );
  }

  Widget _bulkBar(GraphQLClient client, List<dynamic> folders, VoidCallback? refetch, String? projectId) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: SafeArea(top: false, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _BulkBtn(icon: Icons.drive_file_move_outline, label: 'Move', onTap: () async {
        if (projectId == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project not loaded')));
          return;
        }
        final excludeFolderIds = _selFolders.toSet();
        final targetId = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppTheme.surfaceContainerHighest,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (sheetCtx) => _FolderPicker(client: client, projectId: projectId, excludeFolderIds: excludeFolderIds),
        );
        if (targetId == null) return;
        for (final fid in _selFiles.toList()) {
          await client.mutate(MutationOptions(document: gql(_moveFile), variables: {'fileId': fid, 'targetFolderId': targetId}));
        }
        for (final fid in _selFolders.toList()) {
          await client.mutate(MutationOptions(document: gql(_moveFolder), variables: {'folderId': fid, 'targetFolderId': targetId}));
        }
        setState(() { _selFiles.clear(); _selFolders.clear(); _selMode = false; });
        refetch?.call();
      }),
      if (context.read<AuthProvider>().user?.isAdmin == true)
        _BulkBtn(icon: Icons.delete_outline, label: 'Trash', onTap: () async {
          final n = _selFiles.length + _selFolders.length;
          final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            title: const Text('Move to Trash?', style: TextStyle(color: AppTheme.onSurface)),
            content: Text('$n item(s) will be moved to trash. You can restore them later.', style: const TextStyle(color: AppTheme.onSurfaceVariant)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant))),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Trash', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
            ],
          ),
        );
        if (confirmed != true) return;
        for (final fid in _selFiles.toList()) {
          await client.mutate(MutationOptions(document: gql(_moveToTrash), variables: {'fileId': fid}));
        }
        for (final fid in _selFolders.toList()) {
          await client.mutate(MutationOptions(document: gql(_moveFolderToTrash), variables: {'folderId': fid}));
        }
        setState(() { _selFiles.clear(); _selFolders.clear(); _selMode = false; });
        refetch?.call();
      }),
      _BulkBtn(icon: Icons.share, label: 'Share', onTap: () async {
        final links = <Map<String, String>>[];
        for (final fid in _selFiles.toList()) {
          final r = await client.mutate(MutationOptions(document: gql(_createShare), variables: {'input': {'fileId': fid, 'mode': 'PUBLIC'}}));
          final l = r.data?['createShareLink']?['url']?.toString();
          if (l != null) links.add({'name': 'File', 'url': l});
        }
        for (final fid in _selFolders.toList()) {
          final r = await client.mutate(MutationOptions(document: gql(_createFolderShare), variables: {'input': {'folderId': fid, 'mode': 'PUBLIC'}}));
          final l = r.data?['createShareLink']?['url']?.toString();
          if (l != null) links.add({'name': 'Folder', 'url': l});
        }
        if (!context.mounted) return;
        if (links.isEmpty) return;
        await showDialog(context: context, builder: (dCtx) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerHigh,
          title: Text('${links.length} Share Link(s)', style: const TextStyle(color: AppTheme.onSurface)),
          content: SizedBox(width: double.maxFinite, child: ListView.separated(
            shrinkWrap: true,
            itemCount: links.length,
            separatorBuilder: (_, __) => Divider(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.2), height: 1),
            itemBuilder: (_, i) => ListTile(
              dense: true,
              title: Text(links[i]['name']!, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              subtitle: Text(links[i]['url']!, style: const TextStyle(fontSize: 11, color: AppTheme.gold), maxLines: 2),
              trailing: IconButton(icon: const Icon(Icons.copy, color: AppTheme.gold, size: 20), tooltip: 'Copy', onPressed: () {
                Clipboard.setData(ClipboardData(text: links[i]['url']!));
                ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 1)));
              }),
            ),
          )),
          actions: [
            TextButton(onPressed: () {
              Clipboard.setData(ClipboardData(text: links.map((l) => l['url']).join('\n')));
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${links.length} link(s) copied')));
            }, child: const Text('Copy All', style: TextStyle(color: AppTheme.gold))),
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close', style: TextStyle(color: AppTheme.onSurfaceVariant))),
          ],
        ));
        setState(() { _selFiles.clear(); _selFolders.clear(); _selMode = false; });
      }),
    ])),
  );

  void _showPreview(BuildContext ctx, dynamic f, GraphQLClient client) {
    final imgUrl = f['thumbnailPath'] != null ? 'https://mam.haramaintour.com/api/thumbnail/${f['id']}' : 'https://mam.haramaintour.com/api/download?fileIds=${f['id']}&inline=1';
    showDialog(context: ctx, builder: (_) => Dialog(backgroundColor: AppTheme.surfaceContainerHighest, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.contain, errorWidget: (_, __, ___) => Container(height: 200, color: AppTheme.surface, child: const Center(child: Icon(Icons.insert_drive_file, size: 48, color: AppTheme.onSurfaceVariant))))),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text(f['originalName'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          const SizedBox(height: 4), Text(_fmt(f['size'] ?? 0), style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant)), const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _Act(icon: Icons.download, label: 'Download', onTap: () { Navigator.pop(ctx); _downloadWithProgress(context, f); }),
            _Act(icon: Icons.share, label: 'Share', onTap: () async {
              final r = await client.mutate(MutationOptions(document: gql(_createShare), variables: {'input': {'fileId': f['id'], 'mode': 'PUBLIC'}}));
              final l = r.data?['createShareLink']?['url']?.toString();
              if (l != null && ctx.mounted) showDialog(context: ctx, builder: (_) => AlertDialog(backgroundColor: AppTheme.surfaceContainerHigh, title: const Text('Share', style: TextStyle(color: AppTheme.onSurface)), content: Text(l, style: const TextStyle(fontSize: 12, color: AppTheme.gold)), actions: [
                TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: l)); Navigator.pop(ctx); }, child: const Text('Copy')),
              ]));
            }),
            if (context.read<AuthProvider>().user?.isAdmin == true)
              _Act(icon: Icons.delete_outline, label: 'Trash', onTap: () => showDialog(context: ctx, builder: (c) => AlertDialog(backgroundColor: AppTheme.surfaceContainerHigh, title: const Text('Move to Trash?', style: TextStyle(color: AppTheme.onSurface)), actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                TextButton(onPressed: () async { Navigator.pop(c); Navigator.pop(ctx); await client.mutate(MutationOptions(document: gql(_moveToTrash), variables: {'fileId': f['id']})); }, child: const Text('Trash', style: TextStyle(color: Colors.redAccent))),
              ]))),
          ]),
        ])),
      ]),
    ));
  }

  Future<void> _downloadWithProgress(BuildContext context, dynamic file) async {
    final url = 'https://mam.haramaintour.com/api/download?fileIds=${file['id']}';
    final fileName = (file['originalName'] as String?) ?? 'download';
    final mime = (file['mimeType'] as String?) ?? '';
    final isVideo = mime.startsWith('video/');
    final isImage = mime.startsWith('image/');
    if (!context.mounted) return;

    StateSetter? _setDialog;
    int _received = 0;
    int _total = 0;
    bool _done = false;
    bool _savedToGallery = false;
    String? _error;
    String _statusText = 'Downloading...';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          _setDialog = setState;
          final pct = _total > 0 ? (_received / _total * 100).toStringAsFixed(0) : '--';
          final recv = _total > 0 ? (_received / 1048576).toStringAsFixed(1) : '...';
          final tot = _total > 0 ? (_total / 1048576).toStringAsFixed(1) : '?';
          return AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            title: Text(_error != null ? 'Download Failed' : _done ? 'Download Complete!' : _statusText,
                style: TextStyle(color: _error != null ? Colors.redAccent : AppTheme.onSurface, fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(fileName, style: const TextStyle(color: AppTheme.gold, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null,
                minHeight: 6, color: AppTheme.gold, backgroundColor: AppTheme.surfaceContainer,
              )),
              const SizedBox(height: 10),
              Text('$recv / $tot MB  ($pct%)', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
              if (_done) Padding(padding: const EdgeInsets.only(top: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_savedToGallery ? Icons.check_circle : Icons.check_circle, color: AppTheme.gold, size: 20),
                const SizedBox(width: 8),
                Text(_savedToGallery ? 'Saved to Gallery' : 'Saved to Files', style: const TextStyle(color: AppTheme.gold, fontSize: 13)),
              ])),
            ]),
            actions: (_error != null || _done) ? [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppTheme.gold))),
            ] : null,
          );
        },
      ),
    );

    try {
      final token = await const FlutterSecureStorage().read(key: 'auth_token') ?? '';
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      final streamedResp = await client.send(request);
      _total = streamedResp.contentLength ?? 0;
      _setDialog?.call(() {});

      final bytes = <int>[];
      await for (final chunk in streamedResp.stream) {
        bytes.addAll(chunk);
        _received += chunk.length;
        _setDialog?.call(() {});
      }
      client.close();

      // Save to temp first, then move to Gallery if image/video
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';
      await File(savePath).writeAsBytes(bytes);

      if (isImage || isVideo) {
        _statusText = 'Saving to Gallery...';
        _setDialog?.call(() {});
        try {
          if (isVideo) {
            await Gal.putVideo(savePath);
          } else {
            await Gal.putImage(savePath);
          }
          _savedToGallery = true;
          // Clean up temp file after gallery save
          try { await File(savePath).delete(); } catch (_) {}
        } catch (_) {
          // Gallery save failed, file remains in documents dir
        }
      }

      _done = true;
      _setDialog?.call(() {});
    } catch (e) {
      _error = e.toString();
      _setDialog?.call(() {});
    }
  }

  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceVariant, letterSpacing: 0.5)));

  String _fmt(dynamic s) { final b = int.tryParse(s?.toString() ?? '0') ?? 0; if (b < 1048576) return '${(b/1024).toStringAsFixed(0)} KB'; if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB'; return '${(b/1073741824).toStringAsFixed(1)} GB'; }
}

class _StatChip extends StatelessWidget { final String label, sub; const _StatChip({required this.label, required this.sub}); @override Widget build(BuildContext c) => Column(children: [Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.gold)), const SizedBox(height: 2), Text(sub, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant))]); }
class _Act extends StatelessWidget { final IconData icon; final String label; final VoidCallback onTap; const _Act({required this.icon, required this.label, required this.onTap}); @override Widget build(BuildContext c) => InkWell(onTap: onTap, child: Column(children: [Icon(icon, color: AppTheme.gold, size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant))])); }
class _BulkBtn extends StatelessWidget { final IconData icon; final String label; final VoidCallback onTap; const _BulkBtn({required this.icon, required this.label, required this.onTap}); @override Widget build(BuildContext c) => InkWell(onTap: onTap, child: Column(children: [Icon(icon, color: AppTheme.gold, size: 22), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant))])); }

class _FolderTile extends StatelessWidget {
  final dynamic folder; final bool selMode; final bool selected; final VoidCallback onTap; final VoidCallback onLongPress;
  const _FolderTile({required this.folder, required this.selMode, required this.selected, required this.onTap, this.onLongPress = _noop});
  static void _noop() {}
  @override Widget build(BuildContext c) => GestureDetector(
    onTap: onTap, onLongPress: onLongPress,
    child: Container(decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppTheme.gold : AppTheme.blueAccent.withValues(alpha: 0.08))),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
        if (selMode) Container(width: 20, height: 20, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppTheme.gold : Colors.transparent, border: Border.all(color: selected ? AppTheme.gold : AppTheme.onSurfaceVariant.withValues(alpha: 0.3))), child: selected ? const Icon(Icons.check, size: 14, color: Color(0xFF1e1c00)) : null),
        Icon(Icons.folder, color: AppTheme.gold, size: 22), const SizedBox(width: 10),
        Expanded(child: Text(folder['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (!selMode) Text('${folder['totalFiles'] ?? 0}', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
      ])),
    ),
  );
}

class _FileTile extends StatelessWidget {
  final dynamic file; final bool selMode; final bool selected; final VoidCallback onTap; final VoidCallback onLongPress;
  const _FileTile({required this.file, required this.selMode, required this.selected, required this.onTap, this.onLongPress = _noop});
  static void _noop() {}
  @override Widget build(BuildContext c) => GestureDetector(
    onTap: onTap, onLongPress: onLongPress,
    child: Container(margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppTheme.gold : Colors.transparent)),
      child: ListTile(
        leading: selMode ? Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppTheme.gold : Colors.transparent, border: Border.all(color: selected ? AppTheme.gold : AppTheme.onSurfaceVariant.withValues(alpha: 0.3))), child: selected ? const Icon(Icons.check, size: 14, color: Color(0xFF1e1c00)) : null)
            : Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.gold.withValues(alpha: 0.08)), child: Icon(Icons.insert_drive_file, color: AppTheme.gold, size: 22)),
        title: Text(file['originalName'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_fmt(file['size'] ?? 0), style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        trailing: !selMode && file['thumbnailPath'] != null ? ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: 'https://mam.haramaintour.com/api/thumbnail/${file['id']}', width: 40, height: 40, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox())) : null,
      ),
    ),
  );
  static String _fmt(dynamic s) { final b = int.tryParse(s?.toString() ?? '0') ?? 0; if (b < 1048576) return '${(b/1024).toStringAsFixed(0)} KB'; if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB'; return '${(b/1073741824).toStringAsFixed(1)} GB'; }
}

class _FolderPicker extends StatefulWidget {
  final GraphQLClient client;
  final String projectId;
  final Set<String> excludeFolderIds;
  const _FolderPicker({required this.client, required this.projectId, required this.excludeFolderIds});
  @override State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  String? _currentId;
  String _currentName = 'Project Root';
  String? _parentId;
  List<dynamic> _folders = [];
  bool _loading = true;
  final List<({String? id, String name})> _crumbs = [];

  @override void initState() { super.initState(); _loadProject(); }

  Future<void> _loadProject() async {
    setState(() { _loading = true; });
    final res = await widget.client.query(QueryOptions(document: gql(_pickerProject), variables: {'id': widget.projectId}, fetchPolicy: FetchPolicy.networkOnly));
    final p = res.data?['project'];
    setState(() {
      _currentId = null;
      _currentName = p?['title']?.toString() ?? 'Project Root';
      _parentId = null;
      _folders = (p?['folders'] as List<dynamic>?) ?? [];
      _crumbs..clear()..add((id: null, name: _currentName));
      _loading = false;
    });
  }

  Future<void> _loadFolder(String id) async {
    setState(() { _loading = true; });
    final res = await widget.client.query(QueryOptions(document: gql(_pickerFolder), variables: {'id': id}, fetchPolicy: FetchPolicy.networkOnly));
    final f = res.data?['folder'];
    if (f == null) { setState(() { _loading = false; }); return; }
    setState(() {
      _currentId = id;
      _currentName = f['name']?.toString() ?? 'Folder';
      _parentId = f['parent']?['id'] as String?;
      _folders = (f['children'] as List<dynamic>?) ?? [];
      _crumbs.add((id: id, name: _currentName));
      _loading = false;
    });
  }

  Future<void> _goUp() async {
    if (_crumbs.length <= 1) return;
    _crumbs.removeLast();
    final prev = _crumbs.last;
    if (prev.id == null) {
      await _loadProject();
      _crumbs.removeWhere((c) => c.name == prev.name);
      _crumbs.add(prev);
    } else {
      await _loadFolder(prev.id!);
      _crumbs.removeLast();
    }
  }

  @override Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.95, expand: false,
      builder: (_, scrollController) => Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Row(children: [
          if (_crumbs.length > 1) IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.gold, size: 20), tooltip: 'Up', onPressed: _loading ? null : _goUp),
          Expanded(child: Text('Move to: $_currentName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.gold), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ])),
        if (_crumbs.length > 1) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text(_crumbs.map((c) => c.name).join(' › '), style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant), maxLines: 2))),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: Text(_currentId == null ? 'Cannot move to root — pick a folder' : 'Move HERE: $_currentName'),
          style: ElevatedButton.styleFrom(backgroundColor: _currentId == null ? AppTheme.surfaceContainer : AppTheme.gold, foregroundColor: _currentId == null ? AppTheme.onSurfaceVariant : const Color(0xFF1e1c00), padding: const EdgeInsets.symmetric(vertical: 12)),
          onPressed: _currentId == null ? null : () => Navigator.pop(context, _currentId),
        ))),
        Divider(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.2), height: 24),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.gold)) : _folders.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No subfolders here.\nTap "Move HERE" above to drop here, or go back up.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.onSurfaceVariant)))) : ListView.builder(
          controller: scrollController,
          itemCount: _folders.length,
          itemBuilder: (_, i) {
            final f = _folders[i];
            final disabled = widget.excludeFolderIds.contains(f['id']);
            return ListTile(
              leading: Icon(Icons.folder, color: disabled ? AppTheme.onSurfaceVariant : AppTheme.gold),
              title: Text(f['name']?.toString() ?? '', style: TextStyle(color: disabled ? AppTheme.onSurfaceVariant : AppTheme.onSurface, fontWeight: FontWeight.w500)),
              subtitle: disabled ? const Text('(in selection)', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)) : null,
              trailing: disabled ? null : const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVariant, size: 20),
              enabled: !disabled,
              onTap: disabled ? null : () => _loadFolder(f['id'] as String),
            );
          },
        )),
      ]),
    );
  }
}
