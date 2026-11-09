import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 問比較名稱的對話框（另存新的、改名共用）；按取消回傳 null
class SavedComparisonNameDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialName;

  const SavedComparisonNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
  });

  @override
  State<SavedComparisonNameDialog> createState() => _SavedComparisonNameDialogState();
}

class _SavedComparisonNameDialogState extends State<SavedComparisonNameDialog> {
  late final TextEditingController _nameController = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        onSubmitted: (String value) => _confirm(),
        decoration: InputDecoration(
          isDense: true,
          labelText: '名稱',
          hintText: '例如 醫療2',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
