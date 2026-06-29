import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import '../application/chat_controller.dart';
import '../data/chat_api.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';

class ConversationMessagesPage extends StatefulWidget {
  const ConversationMessagesPage({
    super.key,
    required this.conversation,
    required this.controller,
  });

  final Conversation conversation;
  final ChatController controller;

  @override
  State<ConversationMessagesPage> createState() =>
      _ConversationMessagesPageState();
}

class _ConversationMessagesPageState extends State<ConversationMessagesPage> {
  final ChatApi _api = ChatApi();
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<int> _processedIds = {};

  List<ChatMessage> _messages = const [];
  bool _loading = false;
  bool _sending = false;
  Object? _error;

  Conversation get _conv => widget.conversation;

  @override
  void initState() {
    super.initState();
    widget.controller.setActiveConversation(_conv.convId, _onNewMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.updateConversationRead(_conv.convId);
    });
    _loadMessages();
  }

  @override
  void dispose() {
    widget.controller.setActiveConversation(null, null);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await _api.getMessages(_conv.convId);
      if (!mounted) return;
      _processedIds.addAll(msgs.map((m) => m.msgId));
      setState(() => _messages = msgs);
      _scrollToBottom();
      unawaited(_api.markConversationRead(_conv.convId));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onNewMessage(ChatMessage message) {
    if (!_processedIds.add(message.msgId)) return;
    if (!mounted) return;
    setState(() => _messages = [..._messages, message]);
    _scrollToBottom();
    unawaited(_api.markConversationRead(_conv.convId));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    _inputController.clear();
    setState(() => _sending = true);

    try {
      final msg = await _api.sendMessage(_conv.convId, text);
      if (_processedIds.add(msg.msgId)) {
        setState(() => _messages = [..._messages, msg]);
        _scrollToBottom();
      }
      widget.controller.onMessageSent(msg);
    } catch (e) {
      _inputController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งข้อความไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _StoreAvatar(
              displayName: _conv.displayName,
              imageUrl: _apiClient.resolveAssetUrl(_conv.storeImage),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _conv.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    _conv.status == 'open' ? 'กำลังเปิด' : 'ปิดแล้ว',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              _ErrorBanner(error: _error!, onRetry: _loadMessages),
            Expanded(child: _buildMessageList()),
            _InputBar(
              controller: _inputController,
              sending: _sending,
              storeName: _conv.displayName,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              'ยังไม่มีข้อความกับร้านนี้',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _MessageBubble(
        message: _messages[i],
        storeName: _conv.displayName,
        resolveAssetUrl: _apiClient.resolveAssetUrl,
      ),
    );
  }
}

// Ignores the returned Future for fire-and-forget calls.
void unawaited(Future<void> future) {}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.displayName, required this.imageUrl});

  final String displayName;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty
          ? Text(
              displayName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$error',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.storeName,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final String storeName;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              enabled: !sending,
              decoration: InputDecoration(
                hintText: 'ส่งข้อความถึง $storeName...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.storeName,
    required this.resolveAssetUrl,
  });

  final ChatMessage message;
  final String storeName;
  final String Function(String?) resolveAssetUrl;

  bool get _isLegacyRefund =>
      message.senderType == 'bot' &&
      message.body.startsWith('ลูกค้าส่งคำขอคืนสินค้า/คืนเงิน');

  bool get _isBuyer => message.isUser || _isLegacyRefund;

  String get _senderLabel {
    if (_isBuyer) return 'คุณ';
    if (message.senderType == 'bot') return 'ระบบ';
    return storeName;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isBuyer ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isBuyer) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                storeName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isBuyer
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(_senderLabel,
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                if (message.isImage)
                  _ImageContent(
                    imageUrl: resolveAssetUrl(message.body),
                    isBuyer: _isBuyer,
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isBuyer
                          ? const Color(0xFF1A5FA8)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(_isBuyer ? 18 : 4),
                        bottomRight: Radius.circular(_isBuyer ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: _isBuyer ? Colors.white : colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.imageUrl, required this.isBuyer});

  final String imageUrl;
  final bool isBuyer;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openLightbox(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) =>
              loadingProgress == null
                  ? child
                  : Container(
                      width: 200,
                      height: 140,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child:
                          const Center(child: CircularProgressIndicator()),
                    ),
          errorBuilder: (context, error, stackTrace) => Container(
            width: 200,
            height: 100,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  void _openLightbox(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
