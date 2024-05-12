import 'package:flutter/material.dart';
import 'package:ohohoo_toolkit/ohohoo_toolkit.dart';

/// 模型
abstract class ViewModel {
  /// key
  final String key;

  ViewModel({required this.key});

  /// 获取视图，传key，则使用key获取视图
  Widget getView({String? key}) {
    final String viewKey = key ?? this.key;
    return instanceUtil.factory(viewKey, () => setView(viewKey));
  }

  Widget setView(String key);
}

abstract class StatelessView<T extends ViewModel> extends StatelessWidget {
  /// 模型
  final T model;

  const StatelessView(this.model, {super.key});
}

abstract class StatefulView<T extends ViewModel> extends StatefulWidget {
  /// 模型
  final T model;

  const StatefulView(this.model, {super.key});

  @override
  StatefulViewState<T> createState();
}

abstract class StatefulViewState<T extends ViewModel> extends State<StatefulView<T>> {
  T get model => widget.model;
}
