import 'package:flutter/material.dart';

/// 信箱欄位上方的「常用信箱網域 ▾」選單：選了就把 @gmail.com 等網域接到信箱後面
class EmailDomainPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const EmailDomainPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: '快速套用常用電子信箱網域',
      offset: const Offset(0, 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00ADB5)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF00ADB5)
                .withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alternate_email_rounded,
                size: 14,
                color: Color(0xFF00ADB5)),
            SizedBox(width: 4),
            Text(
              '常用信箱網域 ▾',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00ADB5),
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: '@gmail.com',
          child: Row(
            children: [
              Text('🌐 ',
                  style: TextStyle(fontSize: 14)),
              Text('Google ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Expanded(
                child: Text('(@gmail.com)',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12),
                    overflow:
                        TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '@yahoo.com.tw',
          child: Row(
            children: [
              Text('✉️ ',
                  style: TextStyle(fontSize: 14)),
              Text('Yahoo 台灣 ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Expanded(
                child: Text('(@yahoo.com.tw)',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12),
                    overflow:
                        TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '@outlook.com',
          child: Row(
            children: [
              Text('💼 ',
                  style: TextStyle(fontSize: 14)),
              Text('Outlook ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Expanded(
                child: Text('(@outlook.com)',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12),
                    overflow:
                        TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '@icloud.com',
          child: Row(
            children: [
              Text('🍏 ',
                  style: TextStyle(fontSize: 14)),
              Text('Apple iCloud ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Expanded(
                child: Text('(@icloud.com)',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12),
                    overflow:
                        TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
