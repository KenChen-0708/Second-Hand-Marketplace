import '../models/models.dart';
import '../services/support/ai_support_service.dart';
import 'entity_state.dart';

class AiSupportState extends EntityState<SupportChatMessageModel> {
  AiSupportState({AiSupportService? supportService})
    : _supportService = supportService ?? AiSupportService();

  final AiSupportService _supportService;

  bool _isSending = false;

  bool get isSending => _isSending;

  void initialize({UserModel? user}) {
    if (items.isNotEmpty) {
      return;
    }
    setItems([_supportService.buildWelcomeMessage(user: user)]);
  }

  Future<void> restart({UserModel? user}) async {
    setItems([_supportService.buildWelcomeMessage(user: user)]);
    setError(null);
  }

  Future<void> sendMessage({
    required String text,
    UserModel? user,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) {
      return;
    }

    _setSending(true);
    setError(null);

    final userMessage = _supportService.buildUserMessage(trimmed);
    addItem(userMessage);

    try {
      final reply = await _supportService.sendMessage(
        message: trimmed,
        history: items,
        user: user,
      );
      addItem(reply);
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _setSending(false);
    }
  }

  void _setSending(bool value) {
    _isSending = value;
    notifyListeners();
  }
}
