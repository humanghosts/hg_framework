import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hg_framework/ability/toast/toast.dart';
import 'package:hg_framework/hg_framework.dart';
import 'package:hg_framework/service/theme.dart';
import 'package:orientation/orientation.dart';

/// 屏幕方向监听器
abstract class OrientationListener {
  // --- 屏幕方向 ---
  /// 当前屏幕方向 使用这个参数的原因是，当应用禁用左右旋转之后，mediaQuery的方向就不会变化了
  /// 这个参数即使是锁定旋转也可以生效
  DeviceOrientation? deviceOrientation;

  /// 屏幕方向监听订阅
  StreamSubscription<DeviceOrientation>? _subscription;

  /// 初始化
  void onWidgetBuildOrientation() {
    _subscription = OrientationPlugin.onOrientationChange.listen((value) {
      deviceOrientation = value;
    });
  }

  /// 关闭
  void onCloseOrientation() {
    _subscription?.cancel();
  }

  /// 监听屏幕方向
  void listenDeviceOrientation(DeviceOrientation deviceOrientation) {
    if (this.deviceOrientation != deviceOrientation) {
      this.deviceOrientation = deviceOrientation;
      onDeviceOrientationChanged(deviceOrientation);
    }
  }

  /// 屏幕方向改变回调
  void onDeviceOrientationChanged(DeviceOrientation deviceOrientation);
}

/// 主题监听器
abstract class ThemeListener {
  /// 主题服务
  ThemeConfigService themeConfigService = ThemeConfigService.instance;

  /// 主题配置
  ThemeConfig themeConfig = ThemeConfig();

  /// 系统亮度
  Brightness brightness = Brightness.light;

  /// 获取主题
  ThemeTemplate get themeTemplate => themeConfig.templateInUse.value;

  /// 使用Theme.of(Get.context!)获取当前主题数据
  ThemeData get themeData => Theme.of(Get.context!);

  bool get isLightMode => brightness == Brightness.light;

  bool get isDarkMode => brightness == Brightness.dark;

  /// 应用渲染时调用
  void onWidgetBuildTheme() {
    brightness = window.platformBrightness;
  }

  /// 查询主题配置 在应用启动时候初始化完数据库调用
  Future<void> onAppInitTheme() async {
    themeConfig = await ThemeConfigService.instance.find();
  }

  /// 更新主题
  Future<void> updateThemeTemplate(ThemeTemplate template) async {
    String id = template.id.value;
    String inUseId = themeConfig.templateInUse.value.id.value;
    await ThemeTemplateService.instance.dao.save(template);
    if (id == inUseId) themeChangedReRender();
  }

  /// 删除主题
  Future<void> removeThemeTemplate(ThemeTemplate template) async {
    String id = template.id.value;
    String inUseId = themeConfig.templateInUse.value.id.value;
    if (id == inUseId) {
      ToastHelper.toast(msg: "主题正在使用中，无法删除");
    }
    await ThemeTemplateService.instance.dao.remove(template);
  }

  /// 使用主题
  Future<void> useThemeTemplate(ThemeTemplate template) async {
    themeConfig.templateInUse.value = template;
    await ThemeConfigService.instance.dao.save(themeConfig);
    themeChangedReRender();
  }

  /// 添加一个主题
  /// [addToUse] 表示是否同时使用这个主题
  void addThemeTemplate(ThemeTemplate template, {bool addToUse = false}) async {
    Set<String> templateIdMap = themeConfig.templateList.value.map((e) => e.id.value).toSet();
    String id = template.id.value;
    if (templateIdMap.contains(id)) return;
    themeConfig.templateList.add(template);
    if (addToUse) {
      await useThemeTemplate(template);
    } else {
      await ThemeConfigService.instance.dao.save(themeConfig);
    }
  }

  /// 重新构建
  Future<void> rebuild() async {
    themeChangedReRender();
  }

  /// 重新根据主题渲染
  void themeChangedReRender();

  /// 系统亮度调整 用于WidgetsBindingObserver的方法调用
  void didChangePlatformBrightness() {
    Brightness brightness = Get.mediaQuery.platformBrightness;
    if (this.brightness == brightness) return;
    this.brightness = brightness;
    log("brightness changed");
    themeChangedReRender();
  }
}

/// 应用生命周期监听器
abstract class AppLifecycleListener {
  /// 当前app状态
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;

  /// 生命周期改变回调
  @mustCallSuper
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("didChangeAppLifecycleState:$state");
    appLifecycleState = state;
  }
}

/// 蒙版助手
abstract class OverlayHelper {
  /// 蒙版组件
  Map<String, Widget> overlayWidget = {};

  /// 蒙版顺序
  Map<int, Set<String>> indexOverlay = {};

  /// 蒙版顺序
  Map<String, int> overlayIndex = {};

  /// 显示蒙版 index越高越靠上
  void showOverlay({required String key, int index = 0, required Widget widget}) {
    overlayWidget[key] = widget;
    indexOverlay.putIfAbsent(index, () => {}).add(key);
    overlayIndex[key] = index;
    onOverlayReRender();
  }

  /// 关闭蒙版
  void closeOverlay(String key) {
    int? index = overlayIndex[key];
    if (null != index) indexOverlay.putIfAbsent(index, () => {}).remove(key);
    overlayWidget.remove(key);
    overlayIndex.remove(key);
    onOverlayReRender();
  }

  /// 蒙版修改渲染
  void onOverlayReRender();
}

class _AppAnimation extends ChangeNotifier {
  _AppAnimation._();
}

/// 主页控制器
class AppLogic extends GetxController with OrientationListener, ThemeListener, AppLifecycleListener, OverlayHelper {
  AppLogic._();

  static AppLogic get instance => Get.put<AppLogic>(AppLogic._());

  late final AppConfig config;

  static AppConfig get appConfig => instance.config;

  static ThemeTemplate get currentThemeTemplate => instance.themeTemplate;

  /// 应用构建完回调函数
  /// 调用点为[onReady]
  final Map<String, VoidCallback> _onReadyCallback = {};

  /// 注册构建完回调，用于为其他组件提供应用构建回调
  void registerReadyCallback(String key, VoidCallback callback) => _onReadyCallback[key] = callback;

  /// 应用初始化时调用
  /// 调用点为[InitializeHelper.init]
  Future<void> onAppInit(AppConfig appConfig) async {
    config = appConfig;
    await onAppInitTheme();
  }

  /// 应用构建时调用
  /// 调用点为[App.build]
  void onWidgetBuild(BuildContext context) {
    onWidgetBuildTheme();
    onWidgetBuildOrientation();
  }

  @override
  onReady() {
    for (var value in _onReadyCallback.values) {
      value();
    }
  }

  @override
  onClose() {
    onCloseOrientation();
  }

  /// 重新根据主题渲染
  @override
  void themeChangedReRender() => update();

  /// 生命周期改变回调
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log("didChangeAppLifecycleState:$state");
  }

  /// 屏幕方向改变监听
  @override
  void onDeviceOrientationChanged(DeviceOrientation deviceOrientation) {
    log("onDeviceOrientationChanged:$deviceOrientation");
  }

  /// 蒙版更新标识
  Rx<int> overlayUpdateFlag = 0.obs;

  @override
  void onOverlayReRender() {
    overlayUpdateFlag.value++;
  }

  bool get isPhone => Platform.isIOS || Platform.isAndroid;
}
