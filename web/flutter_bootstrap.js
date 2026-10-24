{{flutter_js}}
{{flutter_build_config}}

// 自訂啟動檔（2026-10-25）：不註冊 Flutter 的離線快取（service worker）。
// 原因：離線快取會讓瀏覽器一直用舊版 app，部署新版後要開無痕視窗才看得到（沛沛實測發現）。
// 已經裝過舊快取的瀏覽器，由部署時放上的 tool/service_worker_cleanup.js 清掉。
_flutter.loader.load();
