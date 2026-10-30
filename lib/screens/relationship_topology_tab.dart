import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../router/app_routes.dart';
import '../services/customer_card_summary_service.dart';
import '../services/customer_relationship_service.dart';
import '../services/network_graph_layout.dart';
import '../theme/app_theme.dart';
import 'customers/customer_relationships_dialog.dart';
import 'network/network_graph_painter.dart';
import 'network/network_graph_panels.dart';
import 'network/network_graph_view.dart';

/// 人脈拓撲（網址 `/network`）：黑曜石風格的網狀人脈關係圖
///
/// 2026-10-30 組長決定：拿掉「轉介紹關係」分頁，整頁只留一張圖；轉介紹改成圖上有箭頭的線，
/// 點客戶時資訊卡寫「由誰介紹、介紹了誰」。原本 1,433 行的檔案拆成 `network/` 裡的小檔：
/// 位置計算 `services/network_graph_layout.dart`、畫圖 `network_graph_painter.dart`、
/// 操作 `network_graph_view.dart`、工具列與資訊卡 `network_graph_panels.dart`。
class RelationshipTopologyTab extends StatefulWidget {
  const RelationshipTopologyTab({super.key});

  @override
  State<RelationshipTopologyTab> createState() => _RelationshipTopologyTabState();
}

class _RelationshipTopologyTabState extends State<RelationshipTopologyTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCustomers = [];
  NetworkGraph? _graph;
  final NetworkViewport _viewport = NetworkViewport();

  String? _selectedNodeId;
  final Set<String> _hiddenTypes = {};
  bool _hideLoneNodes = false;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
  }

  @override
  void dispose() {
    _graph?.dispose();
    _viewport.dispose();
    super.dispose();
  }

  Future<void> _loadNetwork() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final List<Map<String, dynamic>> customers = await _fetchCustomers();
      final List<Map<String, dynamic>> relationships = await CustomerRelationshipService.fetchAllRelationships();
      // 資訊卡要顯示客戶階段（保戶／跟進中／未開發）
      await CustomerCardSummaryService.instance.refresh();
      _allCustomers = customers;
      final NetworkGraph? oldGraph = _graph;
      _graph = NetworkGraph.build(customers, relationships);
      _viewport.userHasMoved = false;
      if (oldGraph != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => oldGraph.dispose());
      }
    } catch (error) {
      // 讀不到時保留上一次的圖
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  // 業務員只看自己的客戶；開發者、管理者看全部（和原本規則相同，RLS 另外把關）
  Future<List<Map<String, dynamic>>> _fetchCustomers() async {
    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;
    var query = supabase
        .from('customers')
        .select('id, name, nickname, phone, tags, referral_source_id')
        .isFilter('deleted_at', null);
    if (user != null) {
      final Map<String, dynamic>? profile =
          await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
      final String role = profile?['role']?.toString() ?? 'agent';
      if (role != 'dev' && role != 'admin') query = query.eq('profile_id', user.id);
    }
    final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(await query);
    if (rows.isEmpty) return List<Map<String, dynamic>>.from(OfflineDataStore.customers);
    return rows;
  }

  void _toggleType(String type) {
    setState(() {
      if (!_hiddenTypes.remove(type)) _hiddenTypes.add(type);
    });
  }

  void _toggleLone() {
    setState(() {
      _hideLoneNodes = !_hideLoneNodes;
    });
  }

  // 找人：名字有包含輸入的字就選取他，並移到畫面正中間
  void _search(String keyword) {
    final NetworkGraph? graph = _graph;
    final String trimmedKeyword = keyword.trim();
    if (graph == null || trimmedKeyword.isEmpty) return;
    for (final NetworkGraphNode node in graph.nodes) {
      if (!node.name.contains(trimmedKeyword)) continue;
      setState(() => _selectedNodeId = node.id);
      _viewport.userHasMoved = true;
      _viewport.centerOn(node.position, scale: 1.4);
      return;
    }
  }

  void _fitAll() {
    final NetworkGraph? graph = _graph;
    if (graph == null) return;
    _viewport.userHasMoved = true;
    _viewport.fit(graph.bounds(includeLone: !_hideLoneNodes));
  }

  void _openCustomer(String customerId) {
    GoRouter.of(context).go(AppRoutes.customerPath(customerId));
  }

  Future<void> _manageRelationships(Map<String, dynamic> customer) async {
    await showCustomerRelationshipsDialog(
      context,
      customer: customer,
      allCustomers: _allCustomers,
      onReferralSourceChanged: (String? referralSourceId) {
        customer['referral_source_id'] = referralSourceId;
      },
    );
    // 視窗關掉後重新讀，圖上才看得到剛改的關係
    if (mounted) await _loadNetwork();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final NetworkGraph? graph = _graph;
    Widget body;
    if (_isLoading && graph == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (graph == null || graph.nodes.isEmpty) {
      body = Center(child: Text('目前沒有客戶，新增客戶後這裡會出現人脈關係圖。', style: TextStyle(color: colors.ink3)));
    } else {
      body = _buildGraphArea(graph);
    }

    int loneNodeCount = 0;
    for (final NetworkGraphNode node in graph?.nodes ?? const <NetworkGraphNode>[]) {
      if (node.isLone) loneNodeCount++;
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkGraphToolbar(
              hiddenTypes: _hiddenTypes,
              onToggleType: _toggleType,
              hideLoneNodes: _hideLoneNodes,
              loneNodeCount: loneNodeCount,
              onToggleLone: _toggleLone,
              onSearch: _search,
              onFit: _fitAll,
              onRefresh: _loadNetwork,
            ),
            const SizedBox(height: 12),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphArea(NetworkGraph graph) {
    final AppColors colors = context.appColors;
    final NetworkGraphNode? selectedNode = graph.nodeById[_selectedNodeId];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: NetworkGraphView(
              graph: graph,
              viewport: _viewport,
              selectedNodeId: _selectedNodeId,
              onSelectNode: (String? nodeId) => setState(() => _selectedNodeId = nodeId),
              hiddenTypes: _hiddenTypes,
              hideLoneNodes: _hideLoneNodes,
            ),
          ),
          if (selectedNode != null)
            Positioned(
              top: 12,
              left: 12,
              child: NetworkNodeInfoCard(
                graph: graph,
                node: selectedNode,
                onOpenCustomer: () => _openCustomer(selectedNode.id),
                onManageRelationships: () => _manageRelationships(selectedNode.customer),
                onClose: () => setState(() => _selectedNodeId = null),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Text(
              '滑鼠移到圓點上看他的人脈・按住圓點拖曳・滾輪縮放',
              style: TextStyle(fontSize: 11, color: colors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
