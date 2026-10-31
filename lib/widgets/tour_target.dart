import 'package:flutter/material.dart';

/// 新手導覽要「亮起來」的地方（2026-11-01）
///
/// 用法：把按鈕包起來 `TourTarget(id: 'customers.add', child: 新增客戶按鈕)`，
/// 導覽就能用 [TourTarget.rectOf] 找到它在畫面上的位置，在那裡挖一個亮洞。
/// 同一個 id 同時出現兩次時，以最後出現的為準（不用 GlobalKey，才不會重複報錯）。
class TourTarget extends StatefulWidget {
  final String id;

  /// 跟著這個位置一起記下的資料，例如第一張客戶卡片記客戶編號，導覽才知道要打開誰
  final String? payload;
  final Widget child;

  const TourTarget({super.key, required this.id, this.payload, required this.child});

  static final Map<String, _TourTargetState> _mountedTargets = {};

  /// 這個 id 現在在畫面上的位置；不在畫面上回傳 null
  static Rect? rectOf(String id) {
    final BuildContext? targetContext = _mountedTargets[id]?.context;
    if (targetContext == null) return null;
    final RenderObject? renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  /// 這個 id 的元件（捲動到看得到時用）
  static BuildContext? contextOf(String id) => _mountedTargets[id]?.context;

  /// 這個 id 記下的資料
  static String? payloadOf(String id) => _mountedTargets[id]?.widget.payload;

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  @override
  void initState() {
    super.initState();
    TourTarget._mountedTargets[widget.id] = this;
  }

  @override
  void didUpdateWidget(covariant TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _unregister(oldWidget.id);
      TourTarget._mountedTargets[widget.id] = this;
    }
  }

  @override
  void dispose() {
    _unregister(widget.id);
    super.dispose();
  }

  // 只有記的還是自己時才移除（可能已經被新出現的同 id 元件換掉）
  void _unregister(String id) {
    if (TourTarget._mountedTargets[id] == this) TourTarget._mountedTargets.remove(id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
