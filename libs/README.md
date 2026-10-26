# libs/ — 第三方 CTP SDK（不随仓库分发）

本目录用于存放**上期技术（SimNow）官方 CTP Android SDK** 的二进制文件。
因版权原因，本项目**不包含**这些文件，`libs/` 下的内容均被 `.gitignore` 排除。

## 获取方式

1. 打开 <https://www.simnow.com.cn/static/apiDownload.action>
2. 左侧选「期货期权」→ 顶部切到「Android」标签 → 选版本 **v6.7.13**
3. 下载 `TraderapiMduserapi_6.7.13_Android.zip`

| 校验项 | 值 |
|---|---|
| 文件大小 | 34,259,304 字节 |
| MD5 | `a0a4d2cdbd12e21938d6ce09ec54b2c6` |

> 下载页有瑞数反爬，纯 HTTP 抓取只会拿到挑战页，必须用真实浏览器点开。

## 解包后应放入的文件

从 zip 内的 `TradeApi(...)/Java&Kotlin/TradeApi_release_v1.16-2026-05-06.aar` 解出：

```
libs/
├─ classes.jar                      ← aar 解出的 classes.jar
├─ arm64-v8a/
│  ├─ libthosttraderapi.so
│  ├─ libthosttraderapi_wrap.so
│  └─ libclientencode.so
└─ armeabi-v7a/                     ← 可选，出 32 位包才需要
   ├─ libthosttraderapi.so
   ├─ libthosttraderapi_wrap.so
   └─ libclientencode.so
```

三个 `.so` 缺一不可：

| 文件 | 作用 |
|---|---|
| `libthosttraderapi.so` | CTP 交易核心 |
| `libthosttraderapi_wrap.so` | JNI 胶水层（`swig_module_init` 在这里） |
| `libclientencode.so` | 看穿式信息采集 / 加密模块 |

## 关于 64 位

现代 Android 设备与 RAD Studio 都默认出 64 位包，只放 `arm64-v8a` 三个文件即可。
若只部署 32 位 `.so` 却安装 64 位 APK，运行时会报 `is 32-bit instead of 64-bit`。

## 注意事项

- 这些文件**不要**提交到 Git。如果你想用自己的 fork 打包分发，请自行确认符合上期技术的授权条款。
- `MdApi`（行情）对应的 `libthostmduserapi*.so` 本项目当前未使用，可放可不放。
