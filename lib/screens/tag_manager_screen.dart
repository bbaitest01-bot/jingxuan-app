import 'package:flutter/material.dart';
import '../services/tag_manager_service.dart';
import '../widgets/color_palette_picker.dart';
import '../theme/app_theme.dart';

class TagManagerScreen extends StatefulWidget {
  final bool isDialogMode;
  const TagManagerScreen({super.key, this.isDialogMode = false});

  static Future<void> showAsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750, maxHeight: 620),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const TagManagerScreen(isDialogMode: true),
            ),
          ),
        );
      },
    );
  }

  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  bool _isLoading = true;
  List<TagCategoryModel> _categories = [];
  List<TagItemModel> _tags = [];
  String _selectedCategoryId = 'cat_identity';
  final Set<String> _selectedTagIdsForMerge = {};
  bool _isMergeMode = false;

  String? _bannerMessage;
  String _bannerType = 'green';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await TagManagerService.getCategories();
    final tags = await TagManagerService.getTags();

    setState(() {
      _categories = categories;
      _tags = tags;
      if (_categories.isNotEmpty && !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = _categories.first.id;
      }
      _isLoading = false;
    });
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final hex = hexString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  Color _getCategoryThemeColor(String categoryId) {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => TagCategoryModel(id: '', name: '', colorHex: '#0369A1'),
    );
    return _parseColor(cat.colorHex, context.appColors.acc);
  }

  void _showToast(String message, {String type = 'green'}) {
    if (!mounted) return;
    setState(() {
      _bannerMessage = message;
      _bannerType = type;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          if (_bannerMessage == message) {
            _bannerMessage = null;
          }
        });
      }
    });
  }

  void _openAddCategoryDialog() {
    final nameController = TextEditingController();
    String selectedColorHex = '#0369A1';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('➕ 新增大分類資料夾', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '大分類名稱 (如：理財規劃、售後服務)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                ColorPalettePicker(
                  initialColorHex: selectedColorHex,
                  onColorSelected: (hex) => selectedColorHex = hex,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.ok,
                foregroundColor: context.appColors.onAcc,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final cat = await TagManagerService.addCategory(name, colorHex: selectedColorHex);
                if (!mounted) return;
                Navigator.pop(ctx);

                if (cat == null) {
                  _showToast('大分類「$name」已存在，不可重複建立！', type: 'yellow');
                } else {
                  _showToast('成功建立大分類「$name」！', type: 'green');
                  setState(() {
                    _selectedCategoryId = cat.id;
                  });
                  _loadData();
                }
              },
              child: const Text('確定建立大分類'),
            ),
          ],
        );
      },
    );
  }

  void _openEditCategoryDialog(TagCategoryModel cat) {
    final nameController = TextEditingController(text: cat.name);
    String selectedColorHex = cat.colorHex ?? '#0369A1';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('✏️ 編輯大分類【${cat.name}】', style: const TextStyle(fontWeight: FontWeight.bold)),
          // 固定寬度：對話框會量內容寬度，色盤（可捲動的格子）量不出來會讓視窗畫不出來
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '大分類名稱',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ColorPalettePicker(
                    initialColorHex: selectedColorHex,
                    onColorSelected: (hex) => selectedColorHex = hex,
                  ),
                ],
              ),
            ),
          ),
          // 刪除放左邊、取消與儲存放右邊。
          // 以前在 actions 裡直接放 Spacer，Spacer 只能放在 Row/Column 裡，整個視窗因此畫不出來
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => _confirmDeleteCategory(cat),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('刪除此資料夾'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final ok = await TagManagerService.editCategory(
                      cat.id,
                      newName: name,
                      colorHex: selectedColorHex,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);

                    if (ok) {
                      _showToast('成功更新大分類「$name」！', type: 'green');
                      _loadData();
                    } else {
                      _showToast('更新失敗。', type: 'yellow');
                    }
                  },
                  child: const Text('儲存修改'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(TagCategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              const Text('確認刪除大分類？'),
            ],
          ),
          content: Text('您確定要刪除大分類「${cat.name}」嗎？該分類下的所有子標籤亦將一併移除。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: context.appColors.onAcc),
              onPressed: () async {
                Navigator.pop(ctx); // Close confirmation
                Navigator.pop(context); // Close edit dialog
                await TagManagerService.deleteCategory(cat.id);
                _showToast('大分類「${cat.name}」已刪除！', type: 'red');
                _loadData();
              },
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );
  }

  void _openAddTagDialog() {
    final nameController = TextEditingController();
    String? selectedCustomColor = _categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => TagCategoryModel(id: '', name: '')).colorHex;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('🏷️ 新增子標籤', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '標籤名稱 (例：社團、吃素)',
                    hintText: '請輸入標籤名稱',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                ColorPalettePicker(
                  initialColorHex: selectedCustomColor,
                  onColorSelected: (hex) => selectedCustomColor = hex,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _getCategoryThemeColor(_selectedCategoryId),
                foregroundColor: context.appColors.onAcc,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final result = await TagManagerService.addTag(
                  categoryId: _selectedCategoryId,
                  name: name,
                  colorHex: selectedCustomColor,
                );

                if (!mounted) return;
                Navigator.pop(ctx);
                if (result == null) {
                  _showToast('標籤「$name」已存在，不可重複建立！', type: 'yellow');
                } else {
                  _showToast('成功建立標籤「$name」！', type: 'green');
                  _loadData();
                }
              },
              child: const Text('確定建立'),
            ),
          ],
        );
      },
    );
  }

  void _openEditTagDialog(TagItemModel tag) {
    final nameController = TextEditingController(text: tag.name);
    String selectedCatId = tag.categoryId;
    String? selectedCustomColor = tag.colorHex;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('編輯標籤', style: TextStyle(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setStateModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '標籤名稱',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCatId,
                      decoration: InputDecoration(
                        labelText: '隸屬資料夾 (大分類)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setStateModal(() => selectedCatId = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    ColorPalettePicker(
                      initialColorHex: selectedCustomColor,
                      onColorSelected: (hex) => selectedCustomColor = hex,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final ok = await TagManagerService.editTag(
                  tag.id,
                  newName: newName,
                  colorHex: selectedCustomColor,
                  newCategoryId: selectedCatId,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                if (ok) {
                  _showToast('已成功更新標籤！全站歷史客戶卡片已同步。', type: 'green');
                  _loadData();
                } else {
                  _showToast('已有同名標籤存在，無法儲存。', type: 'yellow');
                }
              },
              child: const Text('儲存修改'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTag(TagItemModel tag) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              const Text('確認刪除標籤？'),
            ],
          ),
          content: Text('您確定要刪除「${tag.name}」標籤嗎？所有已套用此標籤的客戶卡片將一併移除此標籤。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: context.appColors.onAcc),
              onPressed: () async {
                Navigator.pop(ctx);
                await TagManagerService.deleteTag(tag.id);
                _showToast('標籤「${tag.name}」已成功刪除！', type: 'red');
                _loadData();
              },
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );
  }

  void _openMergeDialog() {
    if (_selectedTagIdsForMerge.length < 2) {
      _showToast('請至少勾選 2 個標籤進行合併！', type: 'yellow');
      return;
    }

    final selectedTags = _tags.where((t) => _selectedTagIdsForMerge.contains(t.id)).toList();
    String targetTagName = selectedTags.first.name;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('一鍵合併標籤 (Merge Tags)', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('被選中的同義標籤將全數合併至【目標標準標籤】，所有已貼標籤的客戶卡片會自動更換為標準標籤。'),
                  const SizedBox(height: 16),
                  const Text('請選擇主要保留的目標標籤：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: targetTagName,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: selectedTags.map((t) {
                      return DropdownMenuItem(value: t.name, child: Text(t.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => targetTagName = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('將被合併銷毀的標籤：${selectedTags.where((t) => t.name != targetTagName).map((t) => t.name).join('、')}'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.appColors.ok, foregroundColor: context.appColors.onAcc),
                  onPressed: () async {
                    final sourceNames = selectedTags.where((t) => t.name != targetTagName).map((t) => t.name).toList();
                    Navigator.pop(ctx);

                    final ok = await TagManagerService.mergeTags(
                      targetTagName: targetTagName,
                      sourceTagNames: sourceNames,
                    );

                    if (ok) {
                      _showToast('成功將 ${sourceNames.join('、')} 合併至「$targetTagName」！全站客戶卡片已更新。', type: 'green');
                      setState(() {
                        _selectedTagIdsForMerge.clear();
                        _isMergeMode = false;
                      });
                      _loadData();
                    }
                  },
                  child: const Text('確認合併'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCategory = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => TagCategoryModel(id: 'cat_identity', name: '客戶身分', colorHex: '#0369A1'),
    );
    final themeColor = _getCategoryThemeColor(_selectedCategoryId);
    final categoryTags = _tags.where((t) => t.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏷️ 標籤與資料夾管理器', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: widget.isDialogMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                tooltip: '關閉管理器',
              )
            : null,
        actions: [
          IconButton(
            tooltip: _isMergeMode ? '退出合併模式' : '開啟多標籤合併模式',
            icon: Icon(_isMergeMode ? Icons.close : Icons.merge_type, color: _isMergeMode ? context.appColors.warn : null),
            onPressed: () {
              setState(() {
                _isMergeMode = !_isMergeMode;
                _selectedTagIdsForMerge.clear();
              });
            },
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category Folders Segmented / Tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.appColors.surface2,
                    border: Border(bottom: BorderSide(color: context.appColors.line)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._categories.map((cat) {
                          final isSelected = cat.id == _selectedCategoryId;
                          final color = _parseColor(cat.colorHex, context.appColors.acc);

                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                children: [
                                  Icon(Icons.folder_outlined, size: 16, color: isSelected ? Colors.white : color),
                                  const SizedBox(width: 6),
                                  Text(cat.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                  // 鉛筆只是提示：已選取的分類再點一次就會打開編輯視窗。
                                  // 以前鉛筆自己是按鈕，但點擊會被外層的分類按鈕吃掉，所以按了沒反應
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                                  ],
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: color,
                              backgroundColor: context.appColors.surface,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : (context.appColors.ink2)),
                              onSelected: (selected) {
                                if (isSelected) {
                                  _openEditCategoryDialog(cat);
                                  return;
                                }
                                setState(() {
                                  _selectedCategoryId = cat.id;
                                });
                              },
                            ),
                          );
                        }),
                        ActionChip(
                          avatar: Icon(Icons.add, size: 16, color: context.appColors.ok),
                          label: Text('新增大分類', style: TextStyle(color: context.appColors.ok, fontWeight: FontWeight.bold)),
                          backgroundColor: context.appColors.ok.withOpacity(0.1),
                          side: BorderSide(color: context.appColors.ok),
                          onPressed: _openAddCategoryDialog,
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected Category Info Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activeCategory.name} (共 ${categoryTags.length} 個標籤)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      // 明顯的「編輯／刪除分類」按鈕（資料庫裡真的有這個分類才顯示）
                      if (_categories.any((category) => category.id == activeCategory.id))
                        TextButton.icon(
                          onPressed: () => _openEditCategoryDialog(activeCategory),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('編輯／刪除分類'),
                        ),
                      const Spacer(),
                      if (_isMergeMode)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: context.appColors.warn, foregroundColor: context.appColors.onAcc),
                          onPressed: _openMergeDialog,
                          icon: const Icon(Icons.call_merge, size: 18),
                          label: Text('一鍵合併 (${_selectedTagIdsForMerge.length})'),
                        ),
                    ],
                  ),
                ),

                // Tags Grid/List
                Expanded(
                  child: categoryTags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_outlined, size: 48, color: context.appColors.ink3),
                              const SizedBox(height: 12),
                              Text('該資料夾下尚無標籤，點擊下方「+」按鈕即可新增！', style: TextStyle(color: context.appColors.ink3)),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: categoryTags.map((tag) {
                              final tagColor = tag.colorHex != null ? _parseColor(tag.colorHex, themeColor) : themeColor;
                              final isChecked = _selectedTagIdsForMerge.contains(tag.id);

                              return InkWell(
                                onTap: () {
                                  if (_isMergeMode) {
                                    setState(() {
                                      if (isChecked) {
                                        _selectedTagIdsForMerge.remove(tag.id);
                                      } else {
                                        _selectedTagIdsForMerge.add(tag.id);
                                      }
                                    });
                                  } else {
                                    _openEditTagDialog(tag);
                                  }
                                },
                                onLongPress: () => _confirmDeleteTag(tag),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? context.appColors.warn.withOpacity(0.2)
                                        : (isDark ? tagColor.withOpacity(0.25) : tagColor.withOpacity(0.12)),
                                    border: Border.all(
                                      color: isChecked ? context.appColors.warn : tagColor,
                                      width: isChecked ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isMergeMode) ...[
                                        Icon(isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                                            size: 16, color: isChecked ? context.appColors.warn : tagColor),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        tag.name,
                                        style: TextStyle(
                                          color: isDark ? tagColor.withOpacity(0.9) : tagColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _confirmDeleteTag(tag),
                                        child: Icon(Icons.close, size: 14, color: context.appColors.ink3),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
                if (_bannerMessage != null) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bannerType == 'yellow'
                          ? context.appColors.warn
                          : (_bannerType == 'red' ? Theme.of(context).colorScheme.error : context.appColors.ok),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _bannerType == 'yellow'
                              ? Icons.warning_amber_rounded
                              : (_bannerType == 'red' ? Icons.error_outline_rounded : Icons.check_circle_outline),
                          color: context.appColors.onAcc,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _bannerMessage!,
                            style: TextStyle(
                              color: context.appColors.onAcc,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTagDialog,
        backgroundColor: themeColor,
        // 底色是資料夾自己的顏色（使用者選的），文字維持白色
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('新增子標籤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
