#!/bin/bash
# 编译 Delphi 桥接用的 CtpBridge.jar
# 依赖: JDK 17 (javac/jar) + CTP SDK 的 classes.jar + kotlin-stdlib
set -e
cd "$(dirname "$0")"
JDK="${JDK:-/c/Users/Administrator/WorkBuddy/2026-10-21-15-09-22/tools/jdk/jdk-17.0.20.1+1}"
SDK_JAR="../../simnow/aar/classes.jar"
# CTP 的看穿式"信息采集模块"(com/sfit/ctp/info/*) 是 Kotlin 写的, 需要 kotlin-stdlib。
# 直接合并进本 jar, 这样 Delphi 侧只需部署一个 CtpBridge.jar, 不必再加第三个 jar。
# 1.6.21 仍保留 SDK 用到的那两个老 API(checkParameterIsNotNull / checkExpressionValueIsNotNull),
# 且字节码是 major 50(Java 6), d8 无需脱糖。
KLIB="${KLIB:-../../tools/klib/kotlin-stdlib-1.6.21.jar}"

rm -rf out stubout CtpBridge.jar
mkdir -p out stubout

# 1) 编译期占位类(不打进 jar)
"$JDK/bin/javac" -encoding UTF-8 -source 8 -target 8 -nowarn \
  -d stubout stub/android/content/Context.java

# 2) 编译桥接层
"$JDK/bin/javac" -encoding UTF-8 -source 8 -target 8 -nowarn \
  -d out -cp "$SDK_JAR;stubout" -sourcepath src \
  src/com/dctp/bridge/CtpBridge.java

# 3) 合并 kotlin-stdlib(排除 META-INF, 避免与 MANIFEST 冲突)
#    kotlin-stdlib 是 multi-release jar, 自带 META-INF/versions/9/module-info.class,
#    d8 对 module-info 不友好, 必须清掉。
unzip -o -q "$KLIB" -d out
rm -rf out/META-INF

# 4) 打包(com/dctp + kotlin)
"$JDK/bin/jar" cf CtpBridge.jar -C out .
echo "OK: $(pwd)/CtpBridge.jar"
"$JDK/bin/jar" tf CtpBridge.jar | grep -c "\.class$" | xargs echo "classes:"
"$JDK/bin/jar" tf CtpBridge.jar | grep -E "^com/dctp|^kotlin/jvm/internal/Intrinsics" | head -8
