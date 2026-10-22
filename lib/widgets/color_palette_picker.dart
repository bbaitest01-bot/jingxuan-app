import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPalettePicker extends StatefulWidget {
  final String? initialColorHex;
  final ValueChanged<String> onColorSelected;

  const ColorPalettePicker({
    super.key,
    this.initialColorHex,
    required this.onColorSelected,
  });

  // 16 個建議色（2026-10-22 沛沛同意重排）：前 8 個和新風格同一家族，後 8 個保留鮮豔色。
  // 標籤存的是色碼本身，拿掉的舊建議色已經用在標籤上的照樣顯示；任何顏色也都能用 HEX 輸入
  static const List<String> presetColors = [
    '#1D4877', // 深海藍（預設主題色）
    '#2F6DB5', // 藍（清爽組）
    '#1A7A6C', // 青綠（清爽組）
    '#2B6E4B', // 成功綠
    '#A85A12', // 橘（清爽組）
    '#A8322D', // 危險紅
    '#7A2B3A', // 酒紅
    '#6B717C', // 灰（清爽組）
    '#0369A1', // 天藍
    '#15803D', // 翠綠
    '#B45309', // 琥珀
    '#BE123C', // 玫瑰紅
    '#6B21A8', // 紫
    '#0D9488', // 湖水綠
    '#EA580C', // 亮橘
    '#DB2777', // 粉紅
  ];

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  late String _selectedHex;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _selectedHex = _normalizeHex(widget.initialColorHex) ?? ColorPalettePicker.presetColors.first;
    _hexController = TextEditingController(text: _selectedHex);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String? _normalizeHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    var trimmed = hex.trim().replaceAll('#', '').toUpperCase();
    if (trimmed.length == 6) {
      return '#$trimmed';
    }
    return null;
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return context.appColors.acc;
  }

  void _onSelectHex(String hex) {
    setState(() {
      _selectedHex = hex;
      _hexController.text = hex;
    });
    widget.onColorSelected(hex);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _parseColor(_selectedHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '選擇專屬顏色 (點擊色塊或輸入色碼)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.appColors.ink2,
              ),
            ),
            // Selected Color Preview Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selectedColor.withOpacity(0.2),
                border: Border.all(color: selectedColor, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedHex,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selectedColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 一格一格的色塊（2026-10-22 改用 Wrap）：原本的 GridView 放在對話框裡，
        // 對話框量不出大小，「新增子標籤」等視窗只剩灰色遮罩、整個卡住
        // 寬度剛好一排 8 格：第一排新風格色、第二排鮮豔色
        SizedBox(
          width: 8 * 30 + 7 * 8,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ColorPalettePicker.presetColors.map((String hex) {
              final color = _parseColor(hex);
              final isSelected = hex.toLowerCase() == _selectedHex.toLowerCase();

              return InkWell(
                onTap: () => _onSelectHex(hex),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? context.appColors.ink : Colors.transparent,
                      width: isSelected ? 3.0 : 0.0,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(Icons.check, size: 16, color: Colors.white),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Hex Code Custom Input Box
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hexController,
                decoration: InputDecoration(
                  labelText: 'HEX 自訂色碼',
                  hintText: '#0369A1',
                  prefixIcon: const Icon(Icons.color_lens_outlined, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  final normalized = _normalizeHex(val);
                  if (normalized != null) {
                    setState(() {
                      _selectedHex = normalized;
                    });
                    widget.onColorSelected(normalized);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
