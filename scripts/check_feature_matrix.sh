#!/usr/bin/env bash
set -euo pipefail

echo "=== FEATURE MATRIX COVERAGE SIGNALS ==="

scan () {
  local title="$1"
  local pattern="$2"
  local path="${3:-test integration_test lib}"

  echo ""
  echo "---- ${title} ----"
  echo "pattern: ${pattern}"
  # 只要有命中就输出；没有命中则提示
  if grep -RniE "${pattern}" ${path} >/dev/null 2>&1; then
    grep -RniE "${pattern}" ${path} | head -n 40
    local more
    more=$(grep -RniE "${pattern}" ${path} | wc -l | tr -d ' ')
    if [[ "$more" -gt 40 ]]; then
      echo "... (${more} hits total; showing first 40)"
    fi
  else
    echo "❌ NO HITS"
  fi
}

# --- A 目标分解 / AI目标分解（你已验证 B） ---
scan "目标分解（本地fallback / breakdown flow）" "LocalFallbackBreakdown|breakdown|goal.*break|subGoal|子目标|拆解" "test integration_test"
scan "AI目标分解（成功/异常/网络断开/持久化写入）" "FakeAiServiceSuccess|FakeAiServiceThrows|network down|AiService|AI breakdown|ai_breakdown" "test"
scan "AI分解后写入Hive（sub/task box非空）" "subBox\.values\.isNotEmpty|taskBox\.values\.isNotEmpty|Hive\.openBox|Box<" "test"

# --- B 燃尽/燃起（你已验证 C） ---
scan "燃起图 burnup" "buildBurnup|BurnupService|burnup" "test"
scan "燃尽图 burndown" "buildBurndown|BurnupService|burndown" "test"
scan "图表UI渲染（如果有）" "Chart|fl_chart|recharts|CustomPaint|LineChart|burnup|burndown" "lib test"

# --- C 日历（月/周、点击日程、编辑保存、重启保持）（你已验证 D 的一部分） ---
scan "日历分月/分周 toggle" "daily\.view\.month|daily\.view\.week|Calendar.*month|Calendar.*week" "integration_test test"
scan "点击日程 -> 打开详情" "tap\(find\..*calendar|open.*detail|schedule\.detail|daily\.open|日程详情|詳細" "integration_test test"
scan "编辑并保存（日程）" "保存|save|daily\.edit|schedule\.edit|enterText\(.*title|enterText\(.*topic" "integration_test test"
scan "Hive重启模拟（数据仍在）" "HiveTestEnv|重启模拟|reboot|providers 重建|Hive.*setUp" "integration_test test"

# --- D 目标/日程不同颜色（UI 约束） ---
scan "目标/日程颜色区分" "goal.*color|schedule.*color|task.*color|Color\(|theme.*color|badge.*color" "lib test integration_test"

# --- E 账号体系：Key=邮箱 + 绑定 Google/Apple/Line ---
scan "账号Key=邮箱" "email.*key|Key.*email|userKey|accountKey|primary.*email" "lib test integration_test"
scan "Google 登录" "google|GoogleSignIn|signInWithGoogle|auth.*google" "lib test integration_test"
scan "Apple 登录" "apple|SignInWithApple|signInWithApple|auth.*apple" "lib test integration_test"
scan "LINE 登录" "line|LineSDK|signInWithLine|auth.*line" "lib test integration_test"
scan "第三方入口登录时要求连接邮箱" "connect.*email|link.*email|require.*email|邮箱.*绑定|メール.*連携" "lib test integration_test"
scan "设置用户名" "username|displayName|userName|昵称|ユーザー名" "lib test integration_test"

# --- F 新规登入 / 忘记密码 ---
scan "新规注册" "signUp|register|createUser|新規|注册" "integration_test test lib"
scan "忘记密码" "forgot|resetPassword|password reset|忘记密码|パスワード" "integration_test test lib"

# --- G 日程字段（topic/时间带/全日/地点/参与者/备忘录/提醒/icon/完成度/deadline/照片/优先度） ---
scan "日程字段 topic" "topic" "lib test integration_test"
scan "时间带/全日 all-day" "allDay|all-day|timeRange|startTime|endTime|time帯|終日|全日" "lib test integration_test"
scan "地点 location" "location|place|地点|場所" "lib test integration_test"
scan "参与者 participants" "participants|attendees|参加者" "lib test integration_test"
scan "备忘录 memo/notes" "memo|notes|remark|備考|メモ|备忘录" "lib test integration_test"
scan "提醒 alarm/notification" "alarm|reminder|notification|通知|リマインド" "lib test integration_test"
scan "图标 icon" "icon|Icons\.|SvgPicture|asset.*icon" "lib test integration_test"
scan "完成度 progress" "progress|completion|percent|完成度" "lib test integration_test"
scan "deadline" "deadline|dueDate|締切|期限" "lib test integration_test"
scan "照片 photo/image" "photo|image|pickImage|ImagePicker|camera|アルバム|照片" "lib test integration_test"
scan "优先度 priority" "priority|prio|优先|優先度" "lib test integration_test"

# --- H 目标按用户设定优先度排列 ---
scan "目标按优先度排序" "sort.*priority|order.*priority|priority.*compare|compareTo\(.*priority" "lib test"

# --- I 每天三件事 / 每周三目标 提示 ---
scan "每天三件事" "top3|three things|3 things|每天三件事|三件事" "lib test integration_test"
scan "每周三目标" "weekly.*3|three goals|每周三目标|週.*3" "lib test integration_test"
scan "形成提示（nudge/prompt）" "prompt|nudge|tip|hint|提示" "lib test integration_test"

# --- J 祝日表示（holiday） ---
scan "祝日/holiday 表示" "holiday|祝日|祝祭日|日本の祝日|calendar.*holiday" "lib test integration_test"

# --- K Icon高清化/起始页重新设计/规约整理（通常不靠测试覆盖） ---
scan "起始页/启动页" "splash|launch|起始页|启动页|home.*redesign" "lib test"
scan "icon 高清化" "mipmap|ic_launcher|asset.*icon|app_icon" "android ios pubspec.yaml"

# --- L 登录画面入口 + 连接邮箱 + 设定用户名（更偏集成测试） ---
scan "ログイン画面" "login|ログイン|signIn screen" "lib integration_test test"
scan "入口按钮 keys（google/apple/line）" "login\.(google|apple|line)|auth\.(google|apple|line)" "lib integration_test test"

# --- M 完成/删除目标/日程（编辑页） ---
scan "完成目标/日程" "complete|markDone|isDone|completed|完成" "lib test integration_test"
scan "删除目标/日程" "delete|remove|削除|删除" "lib test integration_test"
scan "编辑页 edit page" "edit.*page|detail.*edit|编辑|編集" "lib test integration_test"

# --- N 提示音选择/头像上限/周开始日选择 ---
scan "提示音选择" "sound|tone|alert.*sound|提示音|サウンド" "lib test integration_test"
scan "用户头像上限" "avatar|max.*avatar|profile.*image|头像.*上限" "lib test integration_test"
scan "周开始日选择" "weekStart|startOfWeek|firstDayOfWeek|週の開始|周开始" "lib test integration_test"

# --- O iOS要求：未登录可正常使用（guest/offline mode） ---
scan "未登录可用（guest/offline）" "guest|anonymous|offline|未登录|未ログイン|without login" "lib test integration_test"

# --- P 用户数据删除 ---
scan "用户data删除" "delete.*data|clear.*data|wipe|reset.*app|データ削除|清空数据" "lib test integration_test"

echo ""
echo "=== DONE ==="
