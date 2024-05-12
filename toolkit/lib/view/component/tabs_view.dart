import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ohohoo_toolkit/ohohoo_toolkit.dart';

/// 标签页模型
class TabsViewModel extends ViewModel {
  /// 标签项
  final List<TabViewModel> tabs;

  /// 根据标签项构建标签页
  final Widget Function(BuildContext context, TabViewModel activeTab) builder;

  /// 新增按钮回调
  final FutureOr<TabViewModel> Function()? onAdd;

  /// 标签页关闭回调，返回是否可以关闭标签页
  final FutureOr<bool> Function(TabViewModel tab)? onRemove;

  /// 最小页签宽度
  final double minTabWidth;

  /// 最大页签宽度
  final double maxTabWidth;

  /// 是否缓存标签页内容，缓存之后builder不会每次都调用
  final bool isCache;

  TabsViewModel({
    required super.key,
    required this.tabs,
    required this.builder,
    this.maxTabWidth = 100,
    this.minTabWidth = 50,
    this.onAdd,
    this.onRemove,
    this.isCache = false,
  }) {
    _tabs.value.addAll(tabs);
  }

  @override
  Widget setView(String key) {
    return TabsView(this, key: ValueKey(key));
  }

  /// 响应式页签
  final RxList<TabViewModel> _tabs = <TabViewModel>[].obs;

  /// 页签显示的数量
  final RxInt _showTabsSize = 0.obs;

  /// 活跃的页签
  final Rx<TabViewModel?> _activeTab = Rx<TabViewModel?>(null);

  /// 添加标签
  void addTab() async {
    FutureOr<TabViewModel> Function()? callback = onAdd;
    if (null == callback) return;
    FutureOr<TabViewModel> result = callback();
    TabViewModel tab = result is Future ? await result : result;
    tabs.add(tab);
    _tabs.add(tab);
  }

  /// 移除标签
  void removeTab(TabViewModel tab) async {
    FutureOr<bool> Function(TabViewModel)? callback = onRemove;
    if (null == callback) return;
    FutureOr<bool> result = callback(tab);
    bool canRemove = result is Future ? await result : result;
    if (!canRemove) return;
    tabs.remove(tab);
    _tabs.remove(tab);
  }

  /// TODO 打开标签
  void openTab(TabViewModel tab) {
    // 切换活跃标签页
    tab.active = true;
    _activeTab.value?.active = false;
    _activeTab.value = tab;
    if (isCache) {}
  }
}

/// 标签页视图
/// 标签页布局规则：
/// 1. 新增标签页在最右侧
/// 2. 超出承载数量的标签页收入左侧下拉框
/// 3. 当打开标签页在左侧下拉框中，将下拉框中页签拿出来插入到最右侧，最左侧页面放入下拉
/// 4. 拿出和放入的过程最好有动画
class TabsView extends StatelessView<TabsViewModel> {
  const TabsView(super.vm, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      return [
        buildDropdownButton(context).width(50),
        buildTabsRow(context, max(0, constrains.maxWidth - 100)),
        buildAddButton(context).width(50),
      ].toRow();
    });
  }

  /// 构建标签页行
  /// 标签页宽度计算规则：
  /// 0. 容器宽度 = 外层容器宽度-新增按钮宽度
  /// 1. 通过容器宽度以及页签数量，计算页签宽度(平均)
  /// 2. 如果宽度大于最大宽度，使用最大宽度
  /// 3. 如果宽度小于最小宽度，左侧显示下拉按钮，宽度使用:
  ///    3.1 (容器宽度-下拉按钮宽度)/最小宽度，使用舍一法获取页签数量 然后使用flex直接平铺即可
  Widget buildTabsRow(BuildContext context, double width) {
    return model._tabs.obx((_) {
      List<TabViewModel> tabs = model._tabs; // 页签
      int tabsSize = tabs.length; // 页签数量
      // 没有页签 返回空容器
      if (tabsSize <= 0) return const SizedBox.shrink();
      double tabWidth = width / tabsSize; // 标签页宽度
      int showTabsSize = 0; // 要显示的页签的数量
      bool isExpanded = true;
      // 宽度小于最小宽度
      if (tabWidth < model.minTabWidth) {
        tabWidth = model.minTabWidth;
        showTabsSize = (width / tabWidth).floor(); // 舍一法取页签数量
        if (showTabsSize <= 0) showTabsSize = 1; // 至少显示一个
        tabWidth = width / showTabsSize; // 真实的宽度
      }
      // 宽度大于最大宽度 或 宽度在范围之内
      else {
        isExpanded = tabWidth < model.maxTabWidth;
        tabWidth = min(model.maxTabWidth, tabWidth);
        showTabsSize = tabsSize;
      }
      model._showTabsSize.value = showTabsSize; // 设置数量
      // 倒序处理页签
      int count = 0;
      List<Widget> children = [];
      for (TabViewModel tab in tabs.reversed) {
        if (count == showTabsSize) break;
        Widget child = buildTab(context, tab, tabWidth);
        children.insert(0, isExpanded ? child.expanded() : child);
        count++;
      }
      return children.toRow().expanded();
    });
  }

  /// 构建单个标签页
  Widget buildTab(BuildContext context, TabViewModel tab, double width) {
    return tab.getView().onTap(() => model.openTab(tab)).constrained(
          maxWidth: model.maxTabWidth,
          minWidth: model.minTabWidth,
          width: width,
        );
  }

  /// 构建新增按钮
  Widget buildAddButton(BuildContext context) {
    return IconButton(onPressed: model.addTab, icon: Icons.add.toIcon());
  }

  /// 构建下拉按钮
  Widget buildDropdownButton(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icons.arrow_drop_down.toIcon(),
    );
  }
}

/// 标签项模型
class TabViewModel extends ViewModel {
  /// 标签页名称
  final Widget name;

  /// 标签页图标
  final Widget icon;

  /// hover的时候的提示
  final Tooltip tooltip;

  TabViewModel({
    required super.key,
    required this.name,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget setView(String key) {
    return TabView(this, key: ValueKey(key));
  }

  /// 是否是激活状态
  final Rx<bool> _isActive = false.obs;

  /// 设置是否活跃
  set active(bool active) => _isActive.value = active;

  /// 是否是活跃页签
  bool get active => _isActive.value;
}

/// 标签项
class TabView extends StatelessView<TabViewModel> {
  const TabView(super.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return model._isActive.obx((_) {
      Widget widget = [
        model.icon,
        model.name.expanded(),
      ].toRow().withTooltip(model.tooltip);
      if (!model.active) return widget;
      return widget.card(margin: const EdgeInsets.all(0));
    });
  }
}
