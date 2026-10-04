import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/character_profile.dart';

/// 初始化 / 编辑人物档案时的草稿。
final characterProvider =
    NotifierProvider<CharacterNotifier, CharacterProfile>(CharacterNotifier.new);

class CharacterNotifier extends Notifier<CharacterProfile> {
  @override
  CharacterProfile build() => CharacterProfile.demo();

  void set(CharacterProfile profile) => state = profile;
}