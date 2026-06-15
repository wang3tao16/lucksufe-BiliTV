import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bili_tv_app/models/video.dart';
import 'home/search_tab.dart';
import 'home/login_tab.dart';
import 'home/local_favorites_tab.dart';
import 'home/bangumi_index_tab.dart';
import 'home/category_tab.dart';
import 'home/local_history_tab.dart';
import '../widgets/tv_focusable_item.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';

/// 主页框架
/// Tab 顺序: 搜索、收藏、索引、影视、历史、用户
class HomeScreen extends StatefulWidget {
  final List<Video>? preloadedVideos;

  const HomeScreen({super.key, this.preloadedVideos});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 1; // 默认选中收藏

  // Tab 图标
  final List<String> _tabIcons = [
    'assets/icons/search.svg',
    'assets/icons/favorite.svg',
    'assets/icons/index.svg',
    'assets/icons/live.svg',
    'assets/icons/history.svg',
    'assets/icons/user.svg',
  ];
  static const int _exitIndex = 6; // 退出按钮索引

  late List<FocusNode> _sideBarFocusNodes;

  final GlobalKey<SearchTabState> _searchTabKey = GlobalKey<SearchTabState>();
  final GlobalKey<LocalFavoritesTabState> _localFavoritesTabKey = GlobalKey<LocalFavoritesTabState>();
  final GlobalKey<BangumiIndexTabState> _bangumiIndexTabKey = GlobalKey<BangumiIndexTabState>();
  final GlobalKey<CategoryTabState> _categoryTabKey = GlobalKey<CategoryTabState>();
  final GlobalKey<LocalHistoryTabState> _localHistoryTabKey = GlobalKey<LocalHistoryTabState>();
  final GlobalKey<LoginTabState> _loginTabKey = GlobalKey<LoginTabState>();

  @override
  void initState() {
    super.initState();
    _sideBarFocusNodes = List.generate(
      _tabIcons.length + 1, // +1 for exit button
      (index) => FocusNode(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      // 初始焦点设在收藏 tab（index 1），与 _selectedTabIndex 一致
      _sideBarFocusNodes[1].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var node in _sideBarFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleSideBarTap(int index) {
    if (index == _selectedTabIndex) {
      // 点击当前 tab → 刷新
      switch (index) {
        case 1:
          _localFavoritesTabKey.currentState?.refresh();
          break;
        case 2:
          _bangumiIndexTabKey.currentState?.refresh();
          break;
        case 3:
          _categoryTabKey.currentState?.refresh();
          break;
        case 4:
          _localHistoryTabKey.currentState?.refresh();
          break;
      }
      return;
    }

    setState(() => _selectedTabIndex = index);
    _sideBarFocusNodes[index].requestFocus();

    // 切换时刷新
    switch (index) {
      case 1:
        _localFavoritesTabKey.currentState?.refresh();
        break;
      case 2:
        _bangumiIndexTabKey.currentState?.refresh();
        break;
      case 3:
        _categoryTabKey.currentState?.refresh();
        break;
      case 4:
        _localHistoryTabKey.currentState?.refresh();
        break;
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('退出确认', style: TextStyle(color: Colors.white)),
        content: const Text('确定要退出应用吗？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('否', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            autofocus: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              SettingsService.clearImageCache();
              SystemNavigator.pop();
            },
            child: const Text('是', style: TextStyle(color: Color(0xFFfb7299))),
          ),
        ],
      ),
    );
  }

  void _refreshCurrentTab() {
    setState(() {});
  }

  /// 重置当前 tab 内容（刷新数据，焦点由侧边栏接管）
  void _resetCurrentTab() {
    switch (_selectedTabIndex) {
      case 1:
        _localFavoritesTabKey.currentState?.refresh();
        break;
      case 2:
        _bangumiIndexTabKey.currentState?.refresh();
        break;
      case 3:
        _categoryTabKey.currentState?.refresh();
        break;
      case 4:
        _localHistoryTabKey.currentState?.refresh();
        break;
      case 5:
        // 设置 tab 无需重置
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 阻止系统默认 pop，不退出
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey != LogicalKeyboardKey.goBack &&
              event.logicalKey != LogicalKeyboardKey.escape) {
            return KeyEventResult.ignored;
          }
          if (Navigator.of(context).canPop()) return KeyEventResult.ignored;

          // 搜索 tab: 保持两步返回逻辑 (结果→键盘→刷新键盘)
          if (_selectedTabIndex == 0) {
            final handled = _searchTabKey.currentState?.handleBack() ?? false;
            if (!handled) {
              // 键盘界面按返回 → 重置搜索 tab 并聚焦侧边栏
              setState(() {});
              _sideBarFocusNodes[0].requestFocus();
            }
            return KeyEventResult.handled;
          }

          // 其他 tab: 重置当前 tab 内容并聚焦侧边栏
          _resetCurrentTab();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _sideBarFocusNodes[_selectedTabIndex].requestFocus();
          });
          return KeyEventResult.handled;
        },
        child: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧边栏
              Expanded(
                flex: 8,
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(_tabIcons.length + 1, (index) {
                      // 退出按钮
                      if (index == _exitIndex) {
                        return TvFocusableItem(
                          iconPath: 'assets/icons/exit.svg',
                          isSelected: false,
                          focusNode: _sideBarFocusNodes[index],
                          isFirst: false,
                          isLast: true,
                          onFocus: () {
                            // 临时清除选中态，避免用户tab显示灰色选中
                            setState(() => _selectedTabIndex = -1);
                          },
                          onTap: _showExitDialog,
                          onMoveRight: null,
                        );
                      }

                      final isUserTab = index == 5;
                      final avatarUrl = isUserTab && AuthService.isLoggedIn
                          ? AuthService.face
                          : null;

                      return TvFocusableItem(
                        iconPath: _tabIcons[index],
                        avatarUrl: avatarUrl,
                        isSelected: _selectedTabIndex == index,
                        focusNode: _sideBarFocusNodes[index],
                        isFirst: index == 0,
                        isLast: false,
                        onFocus: () {
                          setState(() => _selectedTabIndex = index);
                        },
                        onTap: () => _handleSideBarTap(index),
                        onMoveRight: () {
                          switch (index) {
                            case 0:
                              _searchTabKey.currentState?.focusFirstItem();
                              break;
                            case 1:
                              _localFavoritesTabKey.currentState?.focusFirstItem();
                              break;
                            case 2:
                              _bangumiIndexTabKey.currentState?.focusFirstItem();
                              break;
                            case 3:
                              _categoryTabKey.currentState?.focusFirstItem();
                              break;
                            case 4:
                              _localHistoryTabKey.currentState?.focusFirstItem();
                              break;
                            case 5:
                              if (AuthService.isLoggedIn) {
                                _loginTabKey.currentState?.focusFirstCategory();
                              }
                              break;
                          }
                        },
                      );
                    }),
                  ),
                ),
              ),
              // 右侧内容区
              Expanded(flex: 92, child: _buildRightContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightContent() {
    // 退出按钮聚焦时 _selectedTabIndex 为 -1，显示空容器
    if (_selectedTabIndex < 0) return const SizedBox.shrink();
    return IndexedStack(
      index: _selectedTabIndex,
      children: [
        // 0: 搜索
        SearchTab(
          key: _searchTabKey,
          sidebarFocusNode: _sideBarFocusNodes[0],
          onBackToHome: () {
            setState(() {});
            _sideBarFocusNodes[0].requestFocus();
          },
        ),
        // 1: 本地收藏
        LocalFavoritesTab(
          key: _localFavoritesTabKey,
          sidebarFocusNode: _sideBarFocusNodes[1],
          isVisible: _selectedTabIndex == 1,
        ),
        // 2: 番剧索引
        BangumiIndexTab(
          key: _bangumiIndexTabKey,
          sidebarFocusNode: _sideBarFocusNodes[2],
          isVisible: _selectedTabIndex == 2,
        ),
        // 3: 影视分类
        CategoryTab(
          key: _categoryTabKey,
          sidebarFocusNode: _sideBarFocusNodes[3],
          isVisible: _selectedTabIndex == 3,
        ),
        // 4: 本地历史
        LocalHistoryTab(
          key: _localHistoryTabKey,
          sidebarFocusNode: _sideBarFocusNodes[4],
          isVisible: _selectedTabIndex == 4,
        ),
        // 5: 用户/登录
        LoginTab(
          key: _loginTabKey,
          sidebarFocusNode: _sideBarFocusNodes[5],
          onLoginSuccess: _refreshCurrentTab,
        ),
      ],
    );
  }
}
