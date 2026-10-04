import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/monthly_plan.dart';

/// 计划调整页的可编辑计划。由页面显式 load()，避免被全局状态重置。
final planProvider =
    NotifierProvider<PlanNotifier, MonthlyPlan>(PlanNotifier.new);

class PlanNotifier extends Notifier<MonthlyPlan> {
  @override
  MonthlyPlan build() => MonthlyPlan();

  void load(MonthlyPlan plan) {
    state = MonthlyPlan(
      items: plan.items.map((e) => e.copyWith()).toList(),
      hasRandomEvent: plan.hasRandomEvent,
      event: plan.event,
    );
  }

  void setWeight(int index, int weight) {
    if (index < 0 || index >= state.items.length) return;
    state.items[index].weight = weight.clamp(0, 100);
    state = _clone();
  }

  void rename(int index, String name) {
    if (index < 0 || index >= state.items.length) return;
    state.items[index].name = name;
    state = _clone();
  }

  void addItem() {
    if (state.items.length >= 6) return;
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    state.items.add(PlanItem(
      label: labels[state.items.length],
      name: '新事项',
      weight: 0,
      reason: '手动添加',
    ));
    state = _clone();
  }

  void removeAt(int index) {
    if (state.items.length <= 1) return;
    state.items.removeAt(index);
    for (var i = 0; i < state.items.length; i++) {
      state.items[i].label = String.fromCharCode(65 + i);
    }
    state = _clone();
  }

  /// 用于 ReorderableListView 的 onReorderItem：newIndex 已由框架按移除项调整过。
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.items.length) return;
    var target = newIndex;
    if (target < 0) target = 0;
    if (target >= state.items.length) target = state.items.length - 1;
    final item = state.items.removeAt(oldIndex);
    state.items.insert(target, item);
    for (var i = 0; i < state.items.length; i++) {
      state.items[i].label = String.fromCharCode(65 + i);
    }
    state = _clone();
  }

  /// 把总权重归一到 100%（最后一项吸收舍入误差）。
  void normalize() {
    state.renormalize();
    state = _clone();
  }

  /// 平均分配权重。
  void distributeEvenly() {
    if (state.items.isEmpty) return;
    final base = 100 ~/ state.items.length;
    var acc = 0;
    for (var i = 0; i < state.items.length; i++) {
      final w = i == state.items.length - 1 ? 100 - acc : base;
      state.items[i].weight = w;
      acc += w;
    }
    state = _clone();
  }

  MonthlyPlan _clone() => MonthlyPlan(
        items: state.items.map((e) => e.copyWith()).toList(),
        hasRandomEvent: state.hasRandomEvent,
        event: state.event,
      );
}