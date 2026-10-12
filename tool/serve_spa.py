"""本機預覽用的簡易網頁伺服器（給打包好的 build/web 用）。

一般的 python -m http.server 遇到 /customers 這種網址會回 404，
因為硬碟上沒有 customers 這個檔案。這個伺服器在找不到檔案時改回傳 index.html，
讓 Flutter 的網址路由接手，重新整理任何頁面都能正常顯示。

用法：python tool/serve_spa.py [port] [資料夾]
例如：python tool/serve_spa.py 8082 build/web
"""
import http.server
import os
import sys


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    web_root = sys.argv[2] if len(sys.argv) > 2 else "build/web"
    web_root = os.path.abspath(web_root)

    class SinglePageAppHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=web_root, **kwargs)

        def send_head(self):
            # 找不到對應的檔案時，改回傳 index.html
            requested_path = self.translate_path(self.path)
            if not os.path.exists(requested_path):
                self.path = "/index.html"
            return super().send_head()

    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), SinglePageAppHandler)
    print(f"Serving {web_root} at http://localhost:{port} (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
