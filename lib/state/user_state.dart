import '../models/user_model.dart';
import 'entity_state.dart';

class UserState extends EntityState<UserModel> {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  void setCurrentUser(UserModel user) {
    _currentUser = user;
    upsertItem(user);
    setSelectedItem(user);
  }

  void clearCurrentUser() {
    _currentUser = null;
    clearSelectedItem();
    notifyListeners();
  }

  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    upsertItem(user);
    setSelectedItem(user);
  }
}