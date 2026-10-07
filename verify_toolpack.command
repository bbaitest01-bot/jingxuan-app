#!/bin/zsh
# Mac 版工具包校對（Windows 組員請用 verify_toolpack.bat）
cd "$(dirname "$0")"
command -v dart >/dev/null 2>&1 || export PATH="$HOME/development/flutter/bin:$PATH"
dart tool/verify_toolpack.dart
echo ""; echo "按任意鍵關閉..."; read -k1
