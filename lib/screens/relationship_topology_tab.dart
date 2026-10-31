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
import 'network/network_search_results.dart';

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

  /// 搜尋框裡的字；空字串＝沒在搜尋
  String _searchKeyword = '';
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

  // 找人：名字（或綽號）有輸入的字的人全部找出來，圖上一起亮（2026-11-01 沛沛：原本只選第一個，其他同姓的沒標到）
  void _search(String keyword) {
    setState(() {
      _searchKeyword = keyword.trim();
      _selectedNodeId = null;
    });
    _showSearchMatches();
  }

  /// 搜尋找到的人（看不到的沒有關係客戶不算）
  List<NetworkGraphNode> _searchMatches() {
    final NetworkGraph? graph = _graph;
    if (graph == null || _searchKeyword.isEmpty) return const [];
    final List<NetworkGraphNode> matches = [];
    for (final NetworkGraphNode node in graph.nodes) {
      if (_hideLoneNodes && node.isLone) continue;
      final String nickname = node.customer['nickname']?.toString() ?? '';
      if (node.name.contains(_searchKeyword) || nickname.contains(_searchKeyword)) matches.add(node);
    }
    return matches;
  }

  // 把找到的人都移進畫面：一位就放大到中間，好幾位就縮放到全部看得到
  void _showSearchMatches() {
    final List<NetworkGraphNode> matches = _searchMatches();
    if (matches.isEmpty) return;
    _viewport.userHasMoved = true;
    if (matches.length == 1) {
      _viewport.centerOn(matches.first.position, scale: 1.4);
      return;
    }
    Rect area = Rect.fromCircle(center: matches.first.position, radius: matches.first.radius + 30);
    for (final NetworkGraphNode node in matches) {
      area = area.expandToInclude(Rect.fromCircle(center: node.position, radius: node.radius + 30));
    }
    _viewport.fit(area, maxFitScale: 1.4);
  }

  // 點清單裡的名字：選取他、移到中間（和點圓點一樣）
  void _selectSearchResult(NetworkGraphNode node) {
    setState(() => _selectedNodeId = node.id);
    _viewport.userHasMoved = true;
    _viewport.centerOn(node.position, scale: 1.4);
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
    final List<NetworkGraphNode> searchMatches = _searchMatches();
    Set<String>? searchMatchIds;
    if (_searchKeyword.isNotEmpty) {
      searchMatchIds = {};
      for (final NetworkGraphNode node in searchMatches) {
        searchMatchIds.add(node.id);
      }
    }
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
              searchMatchIds: searchMatchIds,
              onSelectNode: (String? nodeId) => setState(() => _selectedNodeId = nodeId),
              hiddenTypes: _hiddenTypes,
              hideLoneNodes: _hideLoneNodes,
            ),
          ),
          // 在搜尋、還沒選人時：左上角是找到的人清單
          if (selectedNode == null && _searchKeyword.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: NetworkSearchResults(
                keyword: _searchKeyword,
                matches: searchMatches,
                onSelect: _selectSearchResult,
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
