import '../models/character_profile.dart';

/// 愿景重校准协议：连续三个月愿景契合度 ≤ 2 星时触发。
class VisionRecalibrationService {
  bool shouldRecalibrate(List<int> recentScores) {
    if (recentScores.length < 3) return false;
    return recentScores
        .sublist(recentScores.length - 3)
        .every((s) => s <= 2);
  }

  String generateDialogue(CharacterProfile profile) {
    return '''
你注意到，这几个月走下来，当初那个目标在你心里的样子已经有些模糊了。
一些新的东西在生长，旧的执念似乎不再能驱动你。我们需要重新对焦一次：

· 你还在追同一个目标吗？如果是，是什么还在支撑你？
· 它是否已经变成了别的东西？如果变了，那个新的方向是什么？
· 有没有一个你一直回避，但内心知道更想要的选择？

当前登记的长期愿景：「${profile.longTermVision}」
请给出你的回答，然后我们将基于此重新校准长期愿景，并继续推演。
''';
  }
}