import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

const _getChats = '''
  query GetChats(\$projectId: ID!) {
    project(id: \$projectId) {
      id
      chats { id message createdAt sender { name role } }
    }
  }
''';

const _sendMessage = '''
  mutation SendMessage(\$projectId: ID!, \$message: String!, \$referencedFileId: ID) {
    sendMessage(projectId: \$projectId, message: \$message, referencedFileId: \$referencedFileId) { id message createdAt sender { name role } }
  }
''';

const _getProjectFiles = '''
  query GetProjectFiles(\$projectId: ID!) {
    project(id: \$projectId) {
      id title
      folders { id name }
      files { id originalName mimeType }
    }
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

class ChatScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  const ChatScreen({super.key, required this.projectId, required this.projectTitle});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String? _refFileId;
  String _refLabel = '';

  Future<void> _send(GraphQLClient client, VoidCallback? refetch) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    final fid = _refFileId;
    _refFileId = null;
    _refLabel = '';
    try {
      await client.mutate(MutationOptions(
        document: gql(_sendMessage),
        variables: {'projectId': widget.projectId, 'message': text, if (fid != null) 'referencedFileId': fid},
      ));
      refetch?.call();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _showMentionPicker(GraphQLClient client) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1d1c18),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Query(
        options: QueryOptions(document: gql(_getProjectFiles), variables: {'projectId': widget.projectId}),
        builder: (result, {refetch, fetchMore}) {
          if (result.isLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFFefe749))));
          final data = result.data?['project'];
          final folders = (data?['folders'] as List<dynamic>?) ?? [];
          final files = (data?['files'] as List<dynamic>?) ?? [];
          return SizedBox(
            height: 360,
            child: Column(children: [
              Container(width: 32, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Tag file or folder', style: TextStyle(color: Colors.white54, fontSize: 14))),
              Expanded(child: ListView(
                children: [
                  if (folders.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('FOLDERS', style: TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 1))),
                  ...folders.map((f) => ListTile(
                    leading: const Icon(Icons.folder, color: Color(0xFFefe749), size: 20),
                    title: Text(f['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      setState(() { _refFileId = f['id']; _refLabel = '[Folder: ${f['name']}]'; });
                      _msgCtrl.text = _msgCtrl.text + ' @${f['name']} ';
                      Navigator.pop(context);
                    },
                  )),
                  if (files.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('FILES', style: TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 1))),
                  ...files.map((f) => ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Color(0xFF42A5F5), size: 20),
                    title: Text(f['originalName'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(f['mimeType'] ?? '', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                    onTap: () {
                      setState(() { _refFileId = f['id']; _refLabel = '[File: ${f['originalName']}]'; });
                      _msgCtrl.text = _msgCtrl.text + ' @${f['originalName']} ';
                      Navigator.pop(context);
                    },
                  )),
                ],
              )),
            ]),
          );
        },
      ),
    );
  }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final client = GraphQLProvider.of(context).value;
    return Query(
      options: QueryOptions(document: gql(_getChats), variables: {'projectId': widget.projectId}, pollInterval: const Duration(seconds: 5)),
      builder: (result, {refetch, fetchMore}) {
        final chats = (result.data?['project']?['chats'] as List<dynamic>?) ?? [];
        return Scaffold(
          backgroundColor: const Color(0xFF141310),
          appBar: AppBar(backgroundColor: const Color(0xFF1d1c18), title: Text(widget.projectTitle.isEmpty ? 'Project Chat' : widget.projectTitle)),
          body: Column(children: [
            Expanded(
              child: chats.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('No messages yet', style: TextStyle(color: Colors.white38, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Start the conversation', style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ]))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: chats.length,
                      itemBuilder: (_, i) {
                        final c = chats[chats.length - 1 - i];
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
                            const SizedBox(height: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF1d1c18), borderRadius: BorderRadius.circular(10)), child: Text(c['message'] ?? '', style: const TextStyle(color: Color(0xFFe0e0e0), fontSize: 14))),
                          ]),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(color: const Color(0xFF1d1c18), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
              child: SafeArea(top: false, child: Column(children: [
                if (_refFileId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFefe749).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.attach_file, color: Color(0xFFefe749), size: 14),
                      const SizedBox(width: 6),
                      Text(_refLabel, style: const TextStyle(color: Color(0xFFefe749), fontSize: 12)),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => setState(() { _refFileId = null; _refLabel = ''; }), child: const Icon(Icons.close, color: Colors.white38, size: 14)),
                    ]),
                  ),
                Row(children: [
                  IconButton(onPressed: () => _showMentionPicker(client), icon: const Icon(Icons.attach_file, color: Colors.white38, size: 22)),
                  Expanded(child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true, fillColor: const Color(0xFF252320),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
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

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
