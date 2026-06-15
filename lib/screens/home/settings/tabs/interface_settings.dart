import 'package:flutter/material.dart';
import '../../../../services/settings_service.dart';
import '../widgets/setting_toggle_row.dart';

class InterfaceSettings extends StatefulWidget {
  final VoidCallback onMoveUp;
  final FocusNode? sidebarFocusNode;

  const InterfaceSettings({
    super.key,
    required this.onMoveUp,
    this.sidebarFocusNode,
  });

  @override
  State<InterfaceSettings> createState() => _InterfaceSettingsState();
}

class _InterfaceSettingsState extends State<InterfaceSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingToggleRow(
          label: '启动动画',
          subtitle: '启动应用时显示动画，关闭则直接进入主页',
          value: SettingsService.splashAnimationEnabled,
          autofocus: true,
          isFirst: true,
          isLast: false,
          onMoveUp: widget.onMoveUp,
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (value) async {
            await SettingsService.setSplashAnimationEnabled(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        SettingToggleRow(
          label: '总是显示时间',
          subtitle: '播放界面右上角总是显示当前时间',
          value: SettingsService.alwaysShowPlayerTime,
          autofocus: false,
          isFirst: false,
          isLast: true,
          onMoveUp: null,
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (value) async {
            await SettingsService.setAlwaysShowPlayerTime(value);
            setState(() {});
          },
        ),
      ],
    );
  }
}
