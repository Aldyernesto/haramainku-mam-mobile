import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'project_detail_screen.dart';

const _getAllChats = '''
  query GetAllChats {
    projects {
      id title
      chats { id message createdAt sender { name role } referencedFile { id originalName } }
    }
  }
''';

const _sendMessage = '''
  mutation SendMessage(\$message: String!, \$referencedFileId: ID) {
    sendMessage(message: \$message, referencedFileId: \$referencedFileId) { id message createdAt sender { name role } referencedFile { id originalName } }
  }
''';

const _searchMention = '''
  query SearchMention(\$query: String!) {
    searchFiles(query: \$query) { id originalName project { title } }
    searchFolders(query: \$query) { id name project { title } }
    projects { id title }
  }
''';

Color _roleColor(String? role) {
  switch (role) {
    case 'ADMIN': return const Color(0xFFefe749);
    case 'FIELD_CREW': return const Color(0xFF4CAF50);
    case 'EDITOR': return const Color(0xFF42A5F5);
    default: return const Color(0xFF9E9E9E);
  }
}

String _roleLabel(String? role) {
  switch (role) {
    case 'ADMIN': return 'ADMIN';
    case 'FIELD_CREW': return 'CREW';
    case 'EDITOR': return 'EDITOR';
    default: return '';
  }
}

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});
  @override State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  String? _refFileId;
  String _refLabel = '';
  String _refEncode = ''; // encoded: type:id:name
  List<dynamic> _mentions = [];
  bool _showMentions = false;
  String _mentionFilter = '';

  void _onTextChanged(String text, GraphQLClient client) {
    // Detect @ mention
    final atIdx = text.lastIndexOf('@');
    if (atIdx >= 0) {
      final afterAt = text.substring(atIdx + 1);
      if (!afterAt.contains(' ')) {
        _mentionFilter = afterAt.toLowerCase();
        _fetchMentions(client);
        setState(() => _showMentions = true);
        return;
      }
    }
    if (_showMentions) setState(() { _showMentions = false; _mentions = []; });
  }

  Future<void> _fetchMentions(GraphQLClient client) async {
    try {
      final result = await client.query(QueryOptions(
        document: gql(_searchMention),
        variables: {'query': _mentionFilter},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!mounted) return;
      final files = (result.data?['searchFiles'] as List<dynamic>?) ?? [];
      final folders = (result.data?['searchFolders'] as List<dynamic>?) ?? [];
      final projects = (result.data?['projects'] as List<dynamic>?) ?? [];
      final filtered = <dynamic>[
        ...projects.where((p) => (p['title'] as String).toLowerCase().contains(_mentionFilter)).map((p) => {...p, '_type': 'project'}),
        ...folders.map((f) => {...f, '_type': 'folder'}),
        ...files.map((f) => {...f, '_type': 'file'}),
      ];
      if (mounted) setState(() => _mentions = filtered.take(6).toList());
    } catch (_) {}
  }

  void _selectMention(dynamic item) {
    final type = item['_type'] as String;
    final name = type == 'project' ? item['title'] : (item['name'] ?? item['originalName']);
    final id = item['id'] as String;
    final projectId = item['project']?['id'] as String? ?? id;
    // Encode: @[type:id:parentId:name]
    _refEncode = '@[$type:$id:$projectId:$name]';
    if (type == 'file') {
      _refFileId = id;
      _refLabel = '$name';
    } else {
      _refFileId = null;
      _refLabel = '$name';
    }
    final txt = _msgCtrl.text;
    final atIdx = txt.lastIndexOf('@');
    if (atIdx >= 0) {
      _msgCtrl.text = '${txt.substring(0, atIdx)}@$name ';
      _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
    }
    setState(() { _showMentions = false; _mentions = []; });
  }

  Future<void> _send(GraphQLClient client, VoidCallback? refetch) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final fid = _refFileId;
      final enc = _refEncode;
      _refFileId = null;
      _refLabel = '';
      _refEncode = '';
      final msg = enc.isNotEmpty ? '$text $enc' : text;
      await client.mutate(MutationOptions(
        document: gql(_sendMessage),
        variables: {'message': msg, if (fid != null) 'referencedFileId': fid},
      ));
      await client.query(QueryOptions(
        document: gql(_getAllChats),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    return Query(
      options: QueryOptions(document: gql(_getAllChats), pollInterval: const Duration(seconds: 5)),
      builder: (result, {refetch, fetchMore}) {
        final projects = (result.data?['projects'] as List<dynamic>?) ?? [];
        // Flatten all chats from all projects into one list sorted by time
        final allMessages = <Map<String, dynamic>>[];
        for (final p in projects) {
          final chats = (p['chats'] as List<dynamic>?) ?? [];
          for (final c in chats) {
            allMessages.add({
              'message': c['message'],
              'sender': c['sender'],
              'createdAt': c['createdAt'],
              'projectTitle': p['title'],
              'projectId': p['id'],
            });
          }
        }
        allMessages.sort((a, b) => (a['createdAt'] as String?)?.compareTo(b['createdAt'] as String) ?? 0);

        // Auto-scroll to bottom on first load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients && allMessages.isNotEmpty) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });

        return Scaffold(
          backgroundColor: const Color(0xFF141310),
          appBar: AppBar(backgroundColor: const Color(0xFF1d1c18), title: const Text('Chat')),
          body: Column(children: [
            Expanded(
              child: allMessages.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('No messages yet', style: TextStyle(color: Colors.white38, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Start the conversation', style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ]))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: allMessages.length,
                      itemBuilder: (_, i) {
                        final c = allMessages[i];
                        final sender = c['sender'];
                        final role = sender?['role'] as String?;
                        final name = sender?['name'] ?? 'Unknown';
                        final color = _roleColor(role);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)))),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              const SizedBox(width: 6),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.25))), child: Text(_roleLabel(role), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color))),
                              const Spacer(),
                              Text(_fmtTime(c['createdAt']), style: const TextStyle(fontSize: 10, color: Colors.white24)),
                            ]),
                            const SizedBox(height: 2),
                            Container(
                              margin: const EdgeInsets.only(left: 36),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFefe749).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                              child: Text(c['projectTitle'] ?? '', style: const TextStyle(fontSize: 9, color: Color(0xFFefe749)))),
                            const SizedBox(height: 4),
                            Container(
                              margin: const EdgeInsets.only(left: 36),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: const Color(0xFF1d1c18), borderRadius: BorderRadius.circular(10)),
                              child: _buildMessage(c['message'] ?? '', c['referencedFile'])),
                          ]),
                        );
                      },
                    ),
            ),
            // Project selector + input
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(color: const Color(0xFF1d1c18), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
              child: SafeArea(top: false, child: Column(children: [
                // @ mention suggestions
                if (_showMentions && _mentions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: const Color(0xFF252320), borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _mentions.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                      itemBuilder: (_, i) {
                        final m = _mentions[i];
                        final icon = m['_type'] == 'folder' ? Icons.folder : m['_type'] == 'file' ? Icons.insert_drive_file : Icons.folder_special;
                        final name = m['_type'] == 'project' ? (m['title'] ?? '') : (m['name'] ?? m['originalName'] ?? '');
                        return ListTile(
                          dense: true,
                          leading: Icon(icon, color: const Color(0xFFefe749), size: 18),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text(m['_type'] ?? '', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                          onTap: () => _selectMention(m),
                        );
                      },
                    ),
                  ),
                // Reference chip
                if (_refFileId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFefe749).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.attach_file, color: Color(0xFFefe749), size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_refLabel, style: const TextStyle(color: Color(0xFFefe749), fontSize: 12))),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => setState(() { _refFileId = null; _refLabel = ''; }), child: const Icon(Icons.close, color: Colors.white38, size: 14)),
                    ]),
                  ),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message... use @ to tag',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true, fillColor: const Color(0xFF252320),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onChanged: (text) => _onTextChanged(text, client),
                    onSubmitted: (_) => _send(client, refetch),
                  )),
                  const SizedBox(width: 8),
                  Container(decoration: BoxDecoration(shape: BoxShape.circle, color: _sending ? const Color(0xFFefe749).withValues(alpha: 0.3) : const Color(0xFFefe749)), child: IconButton(onPressed: _sending ? null : () => _send(client, refetch), icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Color(0xFF141310), size: 20))),
                ]),
              ])),
            ),
          ]),
        );
      },
    );
  }

  void _navigateToRef(String type, String id, String parentId, String name) {
    switch (type) {
      case 'file':
        // Open folder containing the file, or project root
        if (parentId != id) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: parentId, projectTitle: name, isFolder: true)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File: $name'), duration: const Duration(seconds: 2)));
        }
        break;
      case 'folder':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: id, projectTitle: name, isFolder: true)));
        break;
      default:
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: id, projectTitle: name)));
    }
  }

  Widget _buildMessage(String message, dynamic refFile) {
    final parts = <InlineSpan>[];
    // Match encoded refs: @[type:id:parentId:name]
    final refRegex = RegExp(r'@\[(\w+):([^\]]+?):([^\]]+?):([^\]]+?)\]');
    int lastEnd = 0;

    for (final match in refRegex.allMatches(message)) {
      if (match.start > lastEnd) {
        parts.add(TextSpan(text: message.substring(lastEnd, match.start)));
      }
      final type = match.group(1)!;
      final id = match.group(2)!;
      final parentId = match.group(3)!;
      final name = match.group(4)!;
      final icon = type == 'file' ? Icons.insert_drive_file : type == 'folder' ? Icons.folder : Icons.folder_special;
      parts.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: GestureDetector(
        onTap: () => _navigateToRef(type, id, parentId, name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFefe749).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFefe749).withValues(alpha: 0.2))),
          child: Text('$name', style: const TextStyle(color: Color(0xFFefe749), fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      )));
      lastEnd = match.end;
    }
    if (lastEnd < message.length) {
      parts.add(TextSpan(text: message.substring(lastEnd)));
    }
    return Text.rich(TextSpan(style: const TextStyle(color: Color(0xFFe0e0e0), fontSize: 14), children: parts));
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
