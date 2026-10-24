// 清除舊的 Flutter 離線快取（2026-10-25）
// 部署時（.github/workflows/deploy.yml、run_local_web.bat）把這個檔案覆蓋成 build/web/flutter_service_worker.js。
// 瀏覽器發現快取程式有新版時會安裝它：刪掉所有快取、解除註冊，再把開著的分頁重新整理一次，之後就一律載入最新版。
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((key) => caches.delete(key)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach((client) => client.navigate(client.url));
  })());
});
