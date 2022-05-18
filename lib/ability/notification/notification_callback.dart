import 'package:hg_logger/ability/export.dart';

/// 通知点击回调
/// 由于要考虑点击通知冷启动应用的情况，所以通知标识需要做成枚举，回调要静态编码
class NotificationCallback {
  NotificationCallback._();

  /// 日志
  static void _log(String msg) => LogHelper.debug("[本地通知回调]:$msg");

  /// 通知回调方法
  static void callback(String? payload) {
    _log("回调执行，原始负载:$payload");
    NotificationPayload? notificationPayload = NotificationPayload.decode(payload);
    if (null == notificationPayload) {
      _log("负载解码为空，不执行，发送新的通知");
      NotificationHelper.notification();
      return;
    }
    NotificationType type = notificationPayload.type;
    String? realPayload = notificationPayload.payload;
    _log("回调执行");
    type.callback(realPayload);
    _log("发送新通知");
    NotificationHelper.notification();
  }
}
