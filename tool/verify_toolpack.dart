import 'dart:io';

/// 工具包校對：比對 pubspec.yaml、部署設定、本機環境與 jingxuan-vault/工具包.md 是否一致
///
/// 檢查項目：
///   [1/4] pubspec.yaml 每一個直接相依套件的版本 ＝ 工具包.md 寫的版本（不一致算失敗）
///   [2/4] 部署設定 deploy.yml 固定的 Flutter 版本 ＝ 工具包建議版本（不一致算失敗）
///   [3/4] 本機 Flutter、Supabase CLI 版本 ＝ 工具包建議版本（不一致只警告，請照「對齊工具包」更新）
///   [4/4] 印出這台裝置的版本資訊，貼到 jingxuan-vault/工具包更新紀錄.md
void main() {
  print('==============================================');
  print('   開始執行工具包版本與專案配置校對 (Verification)');
  print('==============================================');

  bool hasError = false;

  // 工具包文件位於同層的文件知識庫專案 jingxuan-vault
  const String toolpackPath = '../jingxuan-vault/工具包.md';
  final File toolpackFile = File(toolpackPath);
  if (!toolpackFile.existsSync()) {
    print('❌ 錯誤：找不到 $toolpackPath');
    print('   請確認 jingxuan-vault 與 jingxuan-app 放在同一個上層資料夾（例如 GitHub/）。');
    exit(1);
  }
  final String toolpackContent = toolpackFile.readAsStringSync();

  final File pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ 錯誤：找不到 pubspec.yaml 專案設定檔！');
    exit(1);
  }
  final String pubspecContent = pubspecFile.readAsStringSync();

  // [1/4] 套件版本
  print('\n[1/4] 比對 pubspec.yaml 與工具包.md 的套件版本...');
  final Map<String, String> packageVersions = readDirectDependencyVersions(pubspecContent);
  for (final MapEntry<String, String> package in packageVersions.entries) {
    final RegExp toolpackPattern = RegExp('\\*\\*`${package.key}`\\*\\*.*?\\(`([^`)]+)`\\)');
    final RegExpMatch? toolpackMatch = toolpackPattern.firstMatch(toolpackContent);
    if (toolpackMatch == null) {
      print('❌ 工具包.md 找不到套件 [${package.key}]，請依格式補上：**`${package.key}`** (`${package.value}`)');
      hasError = true;
      continue;
    }
    final String toolpackVersion = toolpackMatch.group(1)!.trim();
    if (toolpackVersion != package.value) {
      print('❌ 版本不對齊：[${package.key}] pubspec.yaml ${package.value}／工具包.md $toolpackVersion');
      hasError = true;
    } else {
      print('✅ ${package.key} ${package.value}');
    }
  }

  // [2/4] 部署設定的 Flutter 版本
  print('\n[2/4] 比對部署設定（.github/workflows/deploy.yml）的 Flutter 版本...');
  final String? docFlutterVersion = RegExp(r'Flutter SDK\s*\(建議版本\s*v?([\d.]+)\)').firstMatch(toolpackContent)?.group(1);
  final String? docSupabaseCliVersion =
      RegExp(r'Supabase CLI\s*\(建議版本\s*v?([\d.]+)\)').firstMatch(toolpackContent)?.group(1);
  if (docFlutterVersion == null) {
    print('❌ 工具包.md 找不到「Flutter SDK (建議版本 vX.Y.Z)」的寫法');
    hasError = true;
  } else {
    print('📌 工具包建議 Flutter：v$docFlutterVersion');
    final File deployFile = File('.github/workflows/deploy.yml');
    final String? deployFlutterVersion = deployFile.existsSync()
        ? RegExp(r"flutter-version:\s*'?([\d.]+)'?").firstMatch(deployFile.readAsStringSync())?.group(1)
        : null;
    if (deployFlutterVersion == null) {
      print('❌ deploy.yml 沒有固定 flutter-version，線上會用最新版編譯');
      hasError = true;
    } else if (deployFlutterVersion != docFlutterVersion) {
      print('❌ deploy.yml 固定 v$deployFlutterVersion，和工具包 v$docFlutterVersion 不一致');
      hasError = true;
    } else {
      print('✅ 部署固定 Flutter v$deployFlutterVersion');
    }
  }

  // [3/4] 本機環境
  print('\n[3/4] 比對本機環境與工具包建議版本...');
  final String? localFlutterVersion = readLocalFlutterVersion();
  final String? localDartVersion = readVersion('dart', ['--version'], RegExp(r'Dart SDK version: ([\d.]+)'));
  final String? localSupabaseCliVersion = readVersion('supabase', ['--version'], RegExp(r'([\d.]+)'));
  warnIfDifferent('Flutter', localFlutterVersion, docFlutterVersion);
  warnIfDifferent('Supabase CLI', localSupabaseCliVersion, docSupabaseCliVersion);

  // [4/4] 這台裝置的版本資訊（貼到工具包更新紀錄的「裝置對齊」表）
  print('\n[4/4] 這台裝置的版本資訊（可貼到 jingxuan-vault/工具包更新紀錄.md「裝置對齊」表，「誰」自己填）：');
  final String today = DateTime.now().toIso8601String().substring(0, 10);
  final String deviceName = Platform.isMacOS ? 'Mac' : (Platform.isWindows ? 'Windows' : Platform.operatingSystem);
  final String flutterCommand = isPuroAvailable() ? 'puro' : 'flutter';
  print('| $today | （誰） | $deviceName（${Platform.operatingSystemVersion.split(' ').take(2).join(' ')}，$flutterCommand） '
      '| ${localFlutterVersion ?? '?'} | ${localDartVersion ?? '?'} | ${localSupabaseCliVersion ?? '未安裝'} | '
      '${hasError ? '❌ 校對失敗' : '✅ 校對成功'} |');

  print('\n校對總結:');
  if (hasError) {
    print('❌ 校對失敗：工具包文件與專案實際設定不符，請修正文件或套件設定！');
    exit(1);
  }
  print('🎉 校對成功！工具包與專案設定一致。');
  exit(0);
}

/// 讀 pubspec.yaml 的 dependencies 與 dev_dependencies 中「名稱: 版本」的套件（sdk: flutter 這種不算）
Map<String, String> readDirectDependencyVersions(String pubspecContent) {
  final Map<String, String> versions = {};
  String? currentSection;
  for (final String line in pubspecContent.split('\n')) {
    final RegExpMatch? sectionMatch = RegExp(r'^([a-z_]+):\s*$').firstMatch(line);
    if (sectionMatch != null) {
      currentSection = sectionMatch.group(1);
      continue;
    }
    if (currentSection != 'dependencies' && currentSection != 'dev_dependencies') {
      continue;
    }
    final RegExpMatch? packageMatch = RegExp(r'''^  ([a-z0-9_]+):\s*['"]?([\^<>=\d][^'"\s#]*)''').firstMatch(line);
    if (packageMatch != null) {
      versions[packageMatch.group(1)!] = packageMatch.group(2)!;
    }
  }
  return versions;
}

bool isPuroAvailable() {
  try {
    return Process.runSync('puro', ['--version'], runInShell: true).exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Windows 組員用 puro，Mac 直接用 flutter
String? readLocalFlutterVersion() {
  final RegExp pattern = RegExp(r'Flutter ([\d.]+)');
  if (isPuroAvailable()) {
    return readVersion('puro', ['flutter', '--version'], pattern);
  }
  return readVersion('flutter', ['--version'], pattern);
}

/// 執行指令並從輸出抓版本號；指令不存在或抓不到回傳 null
String? readVersion(String command, List<String> arguments, RegExp pattern) {
  try {
    final ProcessResult result = Process.runSync(command, arguments, runInShell: true);
    if (result.exitCode != 0) {
      return null;
    }
    final String output = '${result.stdout}${result.stderr}';
    return pattern.firstMatch(output)?.group(1);
  } catch (_) {
    return null;
  }
}

void warnIfDifferent(String toolName, String? localVersion, String? docVersion) {
  if (docVersion == null) {
    print('⚠️ 工具包.md 找不到 $toolName 建議版本');
    return;
  }
  if (localVersion == null) {
    print('⚠️ 本機讀不到 $toolName 版本（沒安裝或不在 PATH），工具包建議 v$docVersion');
    return;
  }
  if (localVersion != docVersion) {
    print('⚠️ $toolName 本機 v$localVersion，工具包建議 v$docVersion（請照「對齊工具包」更新）');
    return;
  }
  print('✅ $toolName v$localVersion');
}
