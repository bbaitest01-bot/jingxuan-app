"""產生專案內建的中文字型子集（assets/fonts/）。

為什麼要做：Flutter 網頁版是自己畫字，用不到瀏覽器裡的系統字。
沒有內建中文字型時，畫面會先顯示方框，再換成 Flutter 臨時下載的備用字，
最後才換成宋體（問題總表 X16）。把字型放進專案後，畫面第一次出現就是正確的字。

收錄的字（避免檔案太大，只收常用的字）：
1. 英數與符號（ASCII）
2. Big5 常用字 5,401 字，以及 Big5 的標點、注音、全形符號
3. 常用的標點、箭頭、圈圈數字、方塊符號
4. 專案程式與翻譯檔裡實際出現的每一個字（lib/、web/index.html）
沒收錄的字（例如客戶名字裡的罕見字）仍會顯示，只是會改用 Flutter 臨時下載的備用字。

使用方式（需要 Python 3 與 fonttools、brotli：pip install fonttools brotli）：
    python tool/build_font_subset.py <原始字型資料夾>

原始字型資料夾要放這些官方檔案（來源：https://github.com/google/fonts ）：
    NotoSansTC-VF.ttf      ← ofl/notosanstc/NotoSansTC[wght].ttf
    NotoSerifTC-VF.ttf     ← ofl/notoseriftc/NotoSerifTC[wght].ttf
    IBMPlexMono-Regular.ttf、IBMPlexMono-Medium.ttf ← ofl/ibmplexmono/
什麼時候要重跑：畫面新增了罕見字、看到某個字跟旁邊的字型不一樣時。
"""

import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_FOLDER = PROJECT_ROOT / "assets" / "fonts"

# 要產生的字型：(原始檔, 粗細, 輸出檔名)。可變字型會先固定成指定粗細
# 內文只做 400 與 700 兩種粗細（每種約 2MB）；畫面要求 500、600 時會自動用最接近的那一種
FONT_JOBS = [
    ("NotoSansTC-VF.ttf", 400, "NotoSansTC-Regular.ttf"),
    ("NotoSansTC-VF.ttf", 700, "NotoSansTC-Bold.ttf"),
    ("NotoSerifTC-VF.ttf", 600, "NotoSerifTC-SemiBold.ttf"),
    ("IBMPlexMono-Regular.ttf", None, "IBMPlexMono-Regular.ttf"),
    ("IBMPlexMono-Medium.ttf", None, "IBMPlexMono-Medium.ttf"),
]

# 常用符號的 Unicode 範圍（起, 迄）
SYMBOL_RANGES = [
    (0x0020, 0x007E),  # 英數與半形符號
    (0x00A0, 0x00FF),  # 拉丁補充（例如 ©、°、×）
    (0x2010, 0x205E),  # 一般標點（破折號、引號、刪節號、‰）
    (0x2190, 0x21FF),  # 箭頭
    (0x2460, 0x24FF),  # 圈圈數字
    (0x25A0, 0x25FF),  # 方塊、圓形等幾何符號
    (0x2713, 0x2716),  # ✓ ✔ ✕ ✖
    (0x3000, 0x303F),  # 中文標點
    (0x3100, 0x312F),  # 注音符號
    (0xFF00, 0xFFEF),  # 全形符號
]


def big5_characters(first_code: int, last_code: int) -> set:
    """把 Big5 編碼範圍內的每一個字轉成文字"""
    characters = set()
    for code in range(first_code, last_code + 1):
        low_byte = code & 0xFF
        # Big5 的第二個位元組只有 0x40～0x7E 與 0xA1～0xFE 是字
        if not (0x40 <= low_byte <= 0x7E or 0xA1 <= low_byte <= 0xFE):
            continue
        try:
            characters.add(code.to_bytes(2, "big").decode("big5"))
        except UnicodeDecodeError:
            pass
    return characters


def project_characters() -> set:
    """專案程式與翻譯檔裡實際出現的每一個字"""
    characters = set()
    source_files = list((PROJECT_ROOT / "lib").rglob("*.dart"))
    source_files += list((PROJECT_ROOT / "lib").rglob("*.arb"))
    source_files.append(PROJECT_ROOT / "web" / "index.html")
    for source_file in source_files:
        text = source_file.read_text(encoding="utf-8", errors="ignore")
        for character in text:
            if ord(character) > 0x7F:
                characters.add(character)
    return characters


def collect_characters() -> str:
    characters = set()
    characters |= big5_characters(0xA140, 0xA3BF)  # Big5 標點、注音、全形符號
    characters |= big5_characters(0xA440, 0xC67E)  # Big5 常用字
    for first_code, last_code in SYMBOL_RANGES:
        for code in range(first_code, last_code + 1):
            characters.add(chr(code))
    characters |= project_characters()
    return "".join(sorted(characters))


def build_font(source_path: Path, weight, output_path: Path, characters: str) -> None:
    font = TTFont(str(source_path))
    # 可變字型：固定成一種粗細，檔案才會變小
    if weight is not None and "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": weight})

    options = subset.Options()
    options.layout_features = ["*"]  # 保留標點擠壓等排版功能
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.hinting = False  # 網頁不需要微調資訊，拿掉可以再省空間
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=characters)
    subsetter.subset(font)
    font.save(str(output_path))


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    source_folder = Path(sys.argv[1]).resolve()
    OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)

    characters = collect_characters()
    print(f"收錄 {len(characters)} 個字")

    for source_name, weight, output_name in FONT_JOBS:
        output_path = OUTPUT_FOLDER / output_name
        build_font(source_folder / source_name, weight, output_path, characters)
        size_in_kb = output_path.stat().st_size // 1024
        print(f"{output_name}: {size_in_kb} KB")


if __name__ == "__main__":
    main()
