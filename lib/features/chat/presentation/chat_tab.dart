import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/auth/presentation/login_page.dart';
import '../application/chat_controller.dart';
import '../domain/conversation.dart';
import 'conversation_messages_page.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.controller});

  final ChatController controller;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _searchController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _filtered(List<Conversation> all) {
    if (_query.isEmpty) return all;
    return all.where((c) {
      final term = _query.toLowerCase();
      return c.displayName.toLowerCase().contains(term) ||
          (c.lastMessage ?? '').toLowerCase().contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthSession.instance,
      builder: (context, _) {
        if (!AuthSession.instance.isLoggedIn) {
          return _LoginPrompt(
            onLoginPressed: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'ค้นหาร้านค้า...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final ctrl = widget.controller;

                  if (ctrl.loading && ctrl.conversations.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final convs = _filtered(ctrl.conversations);

                  if (convs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 52,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty
                                ? 'ไม่พบร้านที่ค้นหา'
                                : 'ยังไม่มีห้องแชทกับร้านค้า',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: ctrl.reload,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: convs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) => _ConversationTile(
                        conv: convs[i],
                        resolveImageUrl: _apiClient.resolveAssetUrl,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConversationMessagesPage(
                              conversation: convs[i],
                              controller: widget.controller,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conv,
    required this.resolveImageUrl,
    required this.onTap,
  });

  final Conversation conv;
  final String Function(String?) resolveImageUrl;
  final VoidCallback onTap;

  String get _lastMessageLabel {
    if (conv.lastMessageType == 'image') return 'ส่งรูปภาพ';
    return conv.lastMessage ?? 'ยังไม่มีข้อความ';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชม.ที่แล้ว';
    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveImageUrl(conv.storeImage);
    final colorScheme = Theme.of(context).colorScheme;
    final unread = conv.unreadCount;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
        child: imageUrl.isEmpty
            ? Text(
                conv.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conv.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatTime(conv.lastMessageAt ?? conv.updatedAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: unread > 0
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              _lastMessageLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread > 0
                    ? colorScheme.onSurface
                    : colorScheme.outline,
                fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Badge.count(count: unread > 99 ? 99 : unread),
          ],
        ],
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text('ห้องแชท', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'เข้าสู่ระบบเพื่อแชทกับร้านค้าและสอบถามสินค้า',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLoginPressed,
              icon: const Icon(Icons.login),
              label: const Text('เข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}
