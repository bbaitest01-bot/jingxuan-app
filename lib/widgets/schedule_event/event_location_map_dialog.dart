import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

/// 行程地點的「地圖定位點選」視窗：搜尋地點、在地圖上點選、確認套用。
///
/// 和原本一樣，搜尋結果或地圖上點到的位置會**立刻**透過 [onLocationPicked] 回傳給行程視窗
/// （不用等按「確認套用」），所以按右上角關閉也會保留已選的地點。
class EventLocationMapDialog extends StatefulWidget {
  /// 打開時的位置（沒有的話用台北 101）
  final double? initialLatitude;
  final double? initialLongitude;

  /// 打開時已填的地點文字（顯示在下方「已選地點」）
  final String initialAddress;

  /// 選到位置時呼叫：緯度、經度、地址文字（逆向查不到地址時是 null，保留原本的文字）
  final void Function(double latitude, double longitude, String? address) onLocationPicked;

  const EventLocationMapDialog({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialAddress,
    required this.onLocationPicked,
  });

  @override
  State<EventLocationMapDialog> createState() => _EventLocationMapDialogState();
}

class _EventLocationMapDialogState extends State<EventLocationMapDialog> {
  // 預設台北 101
  static const LatLng _defaultCenter = LatLng(25.0330, 121.5654);

  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;

  double? _latitude;
  double? _longitude;
  late String _address;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _address = widget.initialAddress;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool get _hasLocation => _latitude != null && _longitude != null;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final List<PlaceSearchResult> results = await LocationService.searchPlaces(
        query,
        userLat: _latitude ?? _defaultCenter.latitude,
        userLng: _longitude ?? _defaultCenter.longitude,
      );
      if (!mounted) return;
      setState(() => _searchResults = results);
      if (results.isNotEmpty) {
        final PlaceSearchResult first = results.first;
        _mapController.move(LatLng(first.latitude, first.longitude), 15);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(PlaceSearchResult item) {
    setState(() {
      _latitude = item.latitude;
      _longitude = item.longitude;
      _address = item.displayName;
      _searchResults = [];
      _searchController.text = item.displayName;
    });
    widget.onLocationPicked(item.latitude, item.longitude, item.displayName);
    _mapController.move(LatLng(item.latitude, item.longitude), 16);
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
    });
    widget.onLocationPicked(point.latitude, point.longitude, null);
    // 逆向地理編碼取得完整中文名稱
    final String? address = await LocationService.reverseGeocode(point.latitude, point.longitude);
    if (mounted && address != null && address.isNotEmpty) {
      setState(() => _address = address);
      widget.onLocationPicked(point.latitude, point.longitude, address);
    }
  }

  void _recenter() {
    if (_hasLocation) {
      _mapController.move(LatLng(_latitude!, _longitude!), 16);
    } else {
      _mapController.move(_defaultCenter, 14);
    }
  }

  // 下方提示文字：已選地點（有地址顯示地址，沒有就顯示經緯度），或操作提示
  String get _selectionText {
    if (!_hasLocation) {
      return '請在地圖上點擊位置，或搜尋地點標註定位點';
    }
    if (_address.isNotEmpty) {
      return '已選地點：$_address';
    }
    return '已選地點：${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(colors),
            const SizedBox(height: 10),
            _buildSearchRow(colors),
            if (_searchResults.isNotEmpty) _buildSearchResults(colors),
            const SizedBox(height: 10),
            Expanded(child: _buildMap(colors)),
            const SizedBox(height: 12),
            _buildConfirmBar(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.map_rounded, color: colors.acc, size: 22),
            const SizedBox(width: 8),
            Text('地圖定位點選', style: AppTextStyles.serif(fontSize: 18, color: colors.ink)),
          ],
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.ink2),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildSearchRow(AppColors colors) {
    Widget suffixIcon = IconButton(
      icon: const Icon(Icons.clear, size: 18),
      onPressed: () => _searchController.clear(),
    );
    if (_isSearching) {
      suffixIcon = const SizedBox(
        width: 16,
        height: 16,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜尋地點 (例: 星巴克, 台北車站)',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: suffixIcon,
            ),
            onSubmitted: _performSearch,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => _performSearch(_searchController.text),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          child: const Text('搜尋'),
        ),
      ],
    );
  }

  Widget _buildSearchResults(AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: colors.line),
        itemBuilder: (BuildContext context, int index) {
          final PlaceSearchResult item = _searchResults[index];
          return ListTile(
            dense: true,
            leading: Icon(Icons.location_on, size: 18, color: colors.acc),
            title: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _selectSearchResult(item),
          );
        },
      ),
    );
  }

  Widget _buildMap(AppColors colors) {
    LatLng initialCenter = _defaultCenter;
    if (_hasLocation) {
      initialCenter = LatLng(_latitude!, _longitude!);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15,
              onTap: (_, LatLng point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.insurance_helper',
              ),
              if (_hasLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_latitude!, _longitude!),
                      width: 40,
                      height: 40,
                      // 地圖圖釘用主題的危險色（紅），和地圖底色分得開
                      child: Icon(Icons.location_pin, color: Theme.of(context).colorScheme.error, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map_modal',
              backgroundColor: colors.surface,
              foregroundColor: colors.acc,
              onPressed: _recenter,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmBar(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _selectionText,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('確認套用此地點', style: TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
        ),
      ],
    );
  }
}
