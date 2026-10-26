#!/usr/bin/env bash
# release.sh — 发版一条命令：升版本号 → 提交 → 打 tag → 推送
#
# 用法:
#   ./scripts/release.sh 1.1.0 "修复 xxx；新增 yyy"
#
# 它做的事:
#   1. 校验工作区干净（有未提交改动会中止，避免把半成品发出去）
#   2. 把 ctpapp.dproj 里 Android / Android64 两处配置的
#      versionName 改成你给的版本号，versionCode 自动 +1
#      （安卓靠 versionCode 判断是否升级，不递增会导致覆盖安装失败）
#   3. 提交这条版本号改动
#   4. 打附注标签 v<版本> 并推送到 GitHub
#   5. 打印 APK 路径与 Release 上传地址
#
# 顺序建议:
#   先改代码 → 编译出 APK 并在真机跑过 → 再运行本脚本 → 上传 APK 到 Release
#   （脚本不负责编译，只保证「tag、dproj 版本号、APK 版本号」三者一致）

set -euo pipefail

cd "$(dirname "$0")/.."

VER="${1:-}"
NOTE="${2:-}"

if [ -z "$VER" ]; then
  echo "用法: ./scripts/release.sh <版本号> [\"更新说明\"]"
  echo "例如: ./scripts/release.sh 1.1.0 \"新增行情页\""
  exit 1
fi

if ! printf '%s' "$VER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "版本号格式不对: $VER （应为 1.2.3 这种三段式）"
  exit 1
fi

TAG="v$VER"

echo "=== 1. 检查工作区 ==="
if [ -n "$(git status --porcelain)" ]; then
  echo "工作区有未提交的改动，先处理掉再发版："
  git status --short
  exit 1
fi
echo "  干净"

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "标签 $TAG 已存在。换一个版本号，或先删除旧标签："
  echo "  git tag -d $TAG && git push origin :refs/tags/$TAG"
  exit 1
fi

echo
echo "=== 2. 升级 ctpapp.dproj 版本号 ==="
python - "$VER" <<'PY'
import re, sys

ver = sys.argv[1]
path = "ctpapp.dproj"
data = open(path, "rb").read()

# 只匹配 Android 的 VerInfo_Keys（只有它同时含 versionCode= 与 versionName=）
pat = re.compile(rb"versionCode=(\d+);versionName=[0-9A-Za-z.\-]+")

old = [int(m.group(1)) for m in pat.finditer(data)]
if not old:
    print("  未找到 versionCode，工程文件结构可能变了，请手动确认")
    raise SystemExit(1)

new_code = max(old) + 1
out = pat.sub(lambda m: b"versionCode=%d;versionName=%s" % (new_code, ver.encode()), data)

if out == data:
    print("  版本号无变化，跳过")
    raise SystemExit(1)

open(path, "wb").write(out)
print("  命中 %d 处（Debug/Release），versionCode %d → %d，versionName → %s"
      % (len(old), max(old), new_code, ver))
PY

echo
echo "=== 3. 提交版本号改动 ==="
git add ctpapp.dproj
git commit -q -m "chore: 版本号升级至 $TAG

versionCode 自增（安卓靠它判断升级），versionName 与 tag 对齐。"
git log --oneline -1

echo
echo "=== 4. 打标签并推送 ==="
git tag -a "$TAG" -m "${TAG}
${NOTE}"
git push -q origin HEAD
git push -q origin "$TAG"
echo "  已推送 $TAG"

echo
echo "=== 5. 下一步：上传 APK 到 GitHub Release ==="
APK=""
for f in Android64/Release/ctpapp/bin/*.apk; do
  [ -f "$f" ] && APK="$f"
done
if [ -n "$APK" ]; then
  echo "  本地 APK: $APK"
  echo "  MD5     : $(md5sum "$APK" 2>/dev/null | cut -d' ' -f1)"
  python - "$APK" <<'PY' || true
import sys, zipfile
try:
    z = zipfile.ZipFile(sys.argv[1])
    m = z.read("AndroidManifest.xml").decode("utf-16-le", "ignore")
    for k in ("versionCode", "versionName"):
        i = m.find(k)
        if i > 0:
            print("  APK 内 %-12s %r" % (k, m[i:i+26]))
except Exception:
    pass
PY
  echo "  若 APK 内版本号与 $VER 不一致，说明编译发生在改版本号之前，请重新编译。"
else
  echo "  尚未找到 APK，请先在 RAD Studio 里编译 Android 64-bit / Release。"
fi
echo
echo "  上传地址: https://github.com/topview999/delphictpapp-v1/releases/new?tag=$TAG"
echo "  下载地址(发布后): https://github.com/topview999/delphictpapp-v1/releases/download/$TAG/delphictpapp.apk"
