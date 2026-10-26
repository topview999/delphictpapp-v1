# CTP 安卓、华为鸿蒙交易客户端（Delphi FMX）

用 Delphi 11.3 / FireMonkey 写的上期技术 CTP 期货交易客户端，直连生产柜台，支持登录、下单、撤单、资金持仓查询。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-Android%2064--bit%20%7C%20HarmonyOS-green)
![Delphi](https://img.shields.io/badge/Delphi-11.3%20FMX-red)
[![Release](https://img.shields.io/github/v/release/topview999/delphictpapp-v1?label=下载%20APK)](https://github.com/topview999/delphictpapp-v1/releases/latest)

> ⚠️ **风险提示**：本项目连接的是**真实交易柜台**，下单即产生真实资金委托。
> 请先在评测环境（SimNow）验证，或仅用最小手数试单。作者不对任何交易损失负责。
>
> 🔒 **切勿提交真实账号密码**。仓库内所有凭证均为占位符，真实配置放 `ctp.ini`（已被 `.gitignore` 排除）。

---

## 下载安装

不想自己编译的话，直接下现成的 APK：

**https://github.com/topview999/delphictpapp-v1/releases/latest**

| 项目 | 说明 |
|---|---|
| 架构 | arm64-v8a（64 位），不支持 32 位老设备 |
| 系统 | Android 6.0+（minSdk 23），华为鸿蒙可安装 APK 的版本已实机验证 |
| 大小 | 约 20 MB |
| 安装 | 允许"未知来源应用"后直接安装；首次运行需授予网络与存储权限 |

安装后把 `ctp.ini` 放到 `/sdcard/Android/data/com.embarcadero.ctpapp/files/`（首次启动会自动生成模板），填好经纪商代码、账号、密码、前置地址即可登录。

---

## 这是什么

CTP（Comprehensive Transaction Platform）是上期技术提供的期货交易 API，国内期货公司的交易终端基本都基于它。官方 Android SDK 只提供 **SWIG 生成的 `.aar`（Java 类 + JNI `.so`）**，其中回调接口 `CThostFtdcTraderSpi` 是 SWIG director 类，**必须在 Java 侧继承**才能收到回调。

Delphi 无法继承 Java 类，所以不能走"Delphi 直接调 C++ 头文件"的常规路线。

本项目的做法是**桥接**：把全部 CTP 逻辑（结构体赋值、回调、错误码）收敛进一个 Java 类 `com.dctp.bridge.CtpBridge`，对 Delphi 只暴露「若干个 String/int 参数的普通方法 + 一行行文本事件」。

```
┌─────────────────────────┐
│ Delphi / FMX UI         │  4 个页签，纯 Pascal，无 JNI 编组
└───────────┬─────────────┘
            │  普通方法调用 + 300ms 轮询 pollEvents()
┌───────────▼─────────────┐
│ Java: CtpBridge         │  结构体赋值 / SPI 回调 / 错误码翻译
└───────────┬─────────────┘
            │  SWIG 绑定
┌───────────▼─────────────┐
│ libthosttraderapi.so    │  官方原生库
└─────────────────────────┘
```

好处是 Delphi 侧代码干净、不碰 JNI 类型转换、不碰 SWIG 结构体翻译；回调也不从原生线程直接跨进 Delphi（用定时器轮询事件队列），规避了 JNI 线程 attach 这类最容易出错的地方。

## 功能

| 页签 | 内容 |
|---|---|
| 连接/登录 | 前置地址（支持多个，自动切换）、BrokerID、账号密码、AuthCode、AppID、生产/评测切换、INI 配置读写 |
| 交易 | 合约、买卖、开平（开仓/平仓/平今/平昨）、限价、数量、下单、撤单、结算单确认 |
| 查询 | 资金、持仓、委托、成交 |
| 日志 | 所有回调按行滚动，`[SYS]` `[ERR]` `[ORDER]` `[TRADE]` `[ACCT]` `[POS]` 前缀分类 |

## 环境要求

- RAD Studio 11.3（Delphi，FMX 框架）
- Android SDK + NDK（随 RAD Studio 安装）
- JDK 17（只在重新编译 Java 桥接层时需要）
- CTP SDK 6.7.13 Android 版（仓库已内置）
- 运行环境：Android 6.0+；**华为鸿蒙（HarmonyOS，支持安装 APK 的版本）已实机验证运行正常**

## 快速开始

### 1. CTP SDK（已内置）

仓库已包含 6.7.13 版所需的全部文件。仅在更新版本时，才需要从 SimNow 下载 `TraderapiMduserapi_6.7.13_Android.zip`（34,259,304 字节，MD5 `a0a4d2cdbd12e21938d6ce09ec54b2c6`），解包后替换 `libs/` 下同名文件：

```
libs/
├─ classes.jar                    ← 来自 aar 的 classes.jar
├─ arm64-v8a/
│   ├─ libthosttraderapi.so
│   ├─ libthosttraderapi_wrap.so
│   └─ libclientencode.so
└─ armeabi-v7a/                   ← 可选，出 32 位包才需要
```

> 本仓库**已内置** `libs/`（`arm64-v8a` + `armeabi-v7a` 全套 `.so` 与 `classes.jar`），克隆后可直接使用。
> 仅在需要更换 SDK 版本时，才需按 **[libs/README.md](libs/README.md)** 重新获取并替换。

### 2. Java 桥接层（已内置预编译 jar）

仓库已内置 `java/CtpBridge.jar`（含 kotlin-stdlib），**不需要 JDK 即可直接编译 APK**。

只有修改了 `java/src` 里的桥接源码时才需要重新构建：

```bash
cd java
./build.sh          # 依赖 javac 17 与 libs/classes.jar
# 产出 CtpBridge.jar（已内置 kotlin-stdlib）
```

### 3. 在 RAD Studio 里打开

用 `ctpapp.dproj` 打开工程，平台选 **Android 64-bit**。然后必须做三件事：

**a. 引入两个 jar**（Project Manager → Android 64-bit Platform → Add）

- `libs/classes.jar`（CTP 官方 SDK）
- `java/CtpBridge.jar`（桥接层，已内置 kotlin-stdlib，**不要再单独加 kotlin**）

**b. 部署三个 .so**（Project → Deployment），远程路径必须是 `library\lib\arm64-v8a\`

| 本地文件 | 远程路径 |
|---|---|
| `libs/arm64-v8a/libthosttraderapi.so` | `library\lib\arm64-v8a\` |
| `libs/arm64-v8a/libthosttraderapi_wrap.so` | `library\lib\arm64-v8a\` |
| `libs/arm64-v8a/libclientencode.so` | `library\lib\arm64-v8a\` |

> 路径必须是 `library\lib\<abi>\`，写成 `lib\` 或默认的 `assets\internal\` 都会在运行时报 `UnsatisfiedLinkError`。

**c. 勾选权限**（Project → Options → Application → Uses Permissions）

`INTERNET`、`ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE`、`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`READ_PHONE_STATE`

> 后三个是 CTP 看穿式信息采集模块（`libclientencode.so`）要求的，缺了会在登录步骤失败。

### 4. 配置登录参数

把 `ctp.ini.sample` 拷到手机：

```
/sdcard/Android/data/com.embarcadero.ctpapp/files/ctp.ini
```

改成自己的账号信息即可，APP 首次运行也会在该位置自动生成一份同格式模板。

### 5. 编译运行

F9。进「连接/登录」页 → 点「连接并登录」。

## 配置说明

```ini
[Login]
Front1 = tcp://<交易前置地址>:41305
Front2 =                                  ; 可填多个，按顺序尝试
BrokerID = <经纪商代码>
UserID = <资金账号>
Password = <交易密码>
InvestorID = <投资者账号>                  ; 留空则取 UserID
UserProductInfo = <客户端产品信息>
AuthCode = <授权码>
AppID = <AppID>
Production = 1                            ; 1 生产 / 0 评测
FlowPath =                                ; 留空 = 应用私有目录/ctpflow
```

几条实现上的细节：

- 键名不区分大小写，`;` `#` 开头为注释，`[Section]` 会被忽略
- 多前置：`Front1/Front2/Front3` 按数字顺序，或重复写 `Front=` 按出现顺序，也支持一行用 `;` 分隔
- 值可写 `tcp://ip:port` 或仅 `ip:port`，缺协议头自动补
- 兼容 UTF-8 BOM 与 Windows CRLF（记事本改过也能解析）
- 日志里密码固定打成 `***`

## 目录结构

```
.
├─ README.md                       本文件
├─ LICENSE                         MIT
├─ ctp.ini.sample                  配置模板
├─ ctpapp.dpr / .dproj             Delphi 工程
├─ MainFmxU.pas / .fmx / .vlb      主窗体：界面 + 交互 + 事件轮询
├─ MyShareUnit.pas                 公共定义
├─ MyShareProcedure.pas            公共过程
├─ u_Toast.pas                     Android Toast 封装
├─ Androidapi.JNI.CtpBridge.pas    Java 桥接类的 Delphi 导入单元
├─ AndroidManifest.template.xml    Android 清单模板
├─ java/
│  ├─ src/com/dctp/bridge/CtpBridge.java   ★ 核心桥接逻辑
│  └─ build.sh                     重新编译 jar
├─ libs/                           CTP SDK 二进制（已内置）
└─ docs/开发笔记.md                 SDK 逆向细节、踩坑记录、错误对照
```

## 常见问题

运行时的 `UnsatisfiedLinkError`、`NoClassDefFoundError: kotlin/jvm/internal/Intrinsics`、`.so` 未打进 APK、dex 方法数超限等问题，都在 **[docs/开发笔记.md](docs/开发笔记.md)** 里逐条记录成因与解法。

最常遇到的一条：

> `No implementation found for void ...swig_module_init()`
> `.so` 没进 APK。检查 Deployment 远程路径是否为 `library\lib\arm64-v8a\`，且平台勾选了 Android 64-bit。

## 参与贡献

Issue 和 PR 都欢迎。提交前请确认：

1. 没有提交任何真实账号、密码、AuthCode、服务器地址
2. 如更新 `libs/` 下的 SDK 文件，请在提交信息里注明版本与来源
3. commit 信息用 `feat:` / `fix:` / `docs:` / `refactor:` 前缀

维护者发版请参考 **[docs/发布流程.md](docs/发布流程.md)**，或直接跑 `./scripts/release.sh <版本号> "更新说明"`。

## 免责声明

本项目仅用于技术学习与个人研究。期货交易具有高风险，使用本软件产生的任何交易结果、资金损失、数据错误，作者不承担任何责任。请遵守你所在地区法律法规及所属期货公司的相关规定。

CTP SDK 的版权归上期技术（SimNow）所有。仓库内 `libs/` 下的 SDK 二进制为其官方发布包的原样副本，仅为方便编译而随仓库提供，不构成任何形式的再授权；如需商用或再分发，请自行向上期技术确认授权条款。

## 开源协议

[MIT](LICENSE) © 2026 topview999
