import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/bilibili_api.dart';
import '../../../services/search_history_service.dart';
import '../../../widgets/tv_keyboard_button.dart';

class SearchKeyboardView extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final VoidCallback? onBackToHome;
  final ValueChanged<String> onSearch;
  final FocusNode? firstItemFocusNode;

  const SearchKeyboardView({
    super.key,
    this.sidebarFocusNode,
    this.onBackToHome,
    required this.onSearch,
    this.firstItemFocusNode,
  });

  @override
  State<SearchKeyboardView> createState() => _SearchKeyboardViewState();
}

class _SearchKeyboardViewState extends State<SearchKeyboardView> {
  String _searchText = '';
  List<String> _suggestions = [];
  final FocusNode _firstSuggestionFocusNode = FocusNode();
  final FocusNode _lastKeyboardButtonFocusNode = FocusNode();
  final List<FocusNode> _gridFocusNodes = List.generate(36, (_) => FocusNode());

  @override
  void dispose() {
    _firstSuggestionFocusNode.dispose();
    _lastKeyboardButtonFocusNode.dispose();
    for (final node in _gridFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  final List<String> _gridKeys = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
  ];

  @override
  void initState() {
    super.initState();
    SearchHistoryService.init(); // Initialize history
  }

  void _handleKeyboardTap(String key) {
    if (key == '后退') {
      if (_searchText.isNotEmpty) {
        setState(() {
          _searchText = _searchText.substring(0, _searchText.length - 1);
        });
        _fetchSuggestions();
      }
    } else if (key == '清空') {
      setState(() {
        _searchText = '';
        _suggestions = [];
      });
    } else if (key == '搜索') {
      if (_searchText.trim().isNotEmpty) {
        SearchHistoryService.add(_searchText.trim());
      }
      widget.onSearch(_searchText);
    } else {
      setState(() {
        _searchText += key;
      });
      _fetchSuggestions();
    }
  }

  Future<void> _fetchSuggestions() async {
    if (_searchText.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final suggestions = await BilibiliApi.getSearchSuggestions(_searchText);

    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
    });
  }

  void _selectSuggestion(String suggestion) {
    setState(() {
      _searchText = suggestion;
    });
    SearchHistoryService.add(suggestion);
    widget.onSearch(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧键盘区
        SizedBox(
          width: 380,
          child: Container(
            color: const Color(0xFF252525),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 搜索输入框
                  Container(
                    height: 50,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _searchText.isEmpty ? '输入关键词搜索...' : _searchText,
                      style: TextStyle(
                        fontSize: 22,
                        color: _searchText.isEmpty
                            ? Colors.white24
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // 清空/后退按钮
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: TvKeyboardButton(
                            label: '清空',
                            focusNode: widget.firstItemFocusNode,
                            onTap: () => _handleKeyboardTap('清空'),
                            onMoveLeft: () =>
                                widget.sidebarFocusNode?.requestFocus(),
                            onMoveDown: () =>
                                _gridFocusNodes[1].requestFocus(),
                            onBack: widget.onBackToHome,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TvKeyboardButton(
                            label: '后退',
                            onTap: () => _handleKeyboardTap('后退'),
                            onMoveRight: () =>
                                _firstSuggestionFocusNode.requestFocus(),
                            onMoveDown: () =>
                                _gridFocusNodes[4].requestFocus(),
                            onBack: widget.onBackToHome,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 字母数字键盘
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _gridKeys.length,
                    itemBuilder: (context, index) => TvKeyboardButton(
                      label: _gridKeys[index],
                      focusNode: _gridFocusNodes[index],
                      onTap: () => _handleKeyboardTap(_gridKeys[index]),
                      onMoveLeft: (index % 6 == 0)
                          ? () => widget.sidebarFocusNode?.requestFocus()
                          : null,
                      onMoveRight: (index % 6 == 5)
                          ? () => _firstSuggestionFocusNode.requestFocus()
                          : null,
                      onBack: widget.onBackToHome,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // 搜索按钮
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: TvActionButton(
                      label: '搜索',
                      color: const Color(0xFFfb7299),
                      focusNode: _lastKeyboardButtonFocusNode,
                      onTap: () => _handleKeyboardTap('搜索'),
                      onMoveLeft: () =>
                          widget.sidebarFocusNode?.requestFocus(),
                      onMoveRight: () =>
                          _firstSuggestionFocusNode.requestFocus(),
                      onBack: widget.onBackToHome,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 右侧建议区
        Expanded(child: _buildSuggestions()),
      ],
    );
  }

  /// 构建搜索建议列表
  Widget _buildSuggestions() {
    // 如果没有建议，显示搜索历史
    if (_suggestions.isEmpty) {
      final history = SearchHistoryService.getAll();
      if (history.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/search.svg',
                width: 80,
                height: 80,
                colorFilter: ColorFilter.mode(
                  Colors.white.withValues(alpha: 0.2),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '输入关键词开始搜索',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        );
      }

      // 显示搜索历史
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '搜索历史',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: history.length + 1, // +1 为清除按钮
                itemBuilder: (context, index) {
                  if (index == history.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: _SuggestionItem(
                        text: '清除搜索记录',
                        icon: Icons.delete_outline,
                        onTap: () async {
                          await SearchHistoryService.clear();
                          setState(() {});
                        },
                        onBack: widget.onBackToHome,
                        onMoveLeft: () => _lastKeyboardButtonFocusNode.requestFocus(),
                      ),
                    );
                  }
                  final item = history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SuggestionItem(
                      text: item,
                      icon: Icons.history,
                      onTap: () => _selectSuggestion(item),
                      onBack: widget.onBackToHome,
                      onMoveLeft: () => _lastKeyboardButtonFocusNode.requestFocus(),
                      focusNode: index == 0 ? _firstSuggestionFocusNode : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      child: ListView.builder(
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SuggestionItem(
              text: suggestion,
              onTap: () => _selectSuggestion(suggestion),
              onBack: widget.onBackToHome,
              onMoveLeft: () => _lastKeyboardButtonFocusNode.requestFocus(),
              focusNode: index == 0 ? _firstSuggestionFocusNode : null,
            ),
          );
        },
      ),
    );
  }
}

/// 搜索建议项
class _SuggestionItem extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onBack;
  final VoidCallback? onMoveLeft;
  final IconData? icon;
  final FocusNode? focusNode;

  const _SuggestionItem({
    required this.text,
    required this.onTap,
    this.onBack,
    this.onMoveLeft,
    this.icon,
    this.focusNode,
  });

  @override
  State<_SuggestionItem> createState() => _SuggestionItemState();
}

class _SuggestionItemState extends State<_SuggestionItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                widget.onMoveLeft != null) {
              widget.onMoveLeft!();
              return KeyEventResult.handled;
            }
            if ((event.logicalKey == LogicalKeyboardKey.escape ||
                    event.logicalKey == LogicalKeyboardKey.goBack ||
                    event.logicalKey == LogicalKeyboardKey.browserBack) &&
                widget.onBack != null) {
              widget.onBack!();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white : Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: _isFocused ? Colors.black54 : Colors.white54,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: _isFocused ? Colors.black : Colors.white70,
                    fontSize: 16,
                    fontWeight: _isFocused
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
