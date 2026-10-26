package com.dctp.bridge;

import android.content.Context;

import com.sfit.ctp.thosttraderapi.CThostFtdcInputOrderActionField;
import com.sfit.ctp.thosttraderapi.CThostFtdcInputOrderField;
import com.sfit.ctp.thosttraderapi.CThostFtdcInvestorPositionField;
import com.sfit.ctp.thosttraderapi.CThostFtdcOrderField;
import com.sfit.ctp.thosttraderapi.CThostFtdcQryInvestorPositionField;
import com.sfit.ctp.thosttraderapi.CThostFtdcQryOrderField;
import com.sfit.ctp.thosttraderapi.CThostFtdcQryTradeField;
import com.sfit.ctp.thosttraderapi.CThostFtdcQryTradingAccountField;
import com.sfit.ctp.thosttraderapi.CThostFtdcReqAuthenticateField;
import com.sfit.ctp.thosttraderapi.CThostFtdcReqUserLoginField;
import com.sfit.ctp.thosttraderapi.CThostFtdcRspAuthenticateField;
import com.sfit.ctp.thosttraderapi.CThostFtdcRspInfoField;
import com.sfit.ctp.thosttraderapi.CThostFtdcRspUserLoginField;
import com.sfit.ctp.thosttraderapi.CThostFtdcSettlementInfoConfirmField;
import com.sfit.ctp.thosttraderapi.CThostFtdcTradeField;
import com.sfit.ctp.thosttraderapi.CThostFtdcTraderApi;
import com.sfit.ctp.thosttraderapi.CThostFtdcTraderSpi;
import com.sfit.ctp.thosttraderapi.CThostFtdcTradingAccountField;
import com.sfit.ctp.thosttraderapi.CThostFtdcUserLogoutField;
import com.sfit.ctp.thosttraderapi.THOST_TE_RESUME_TYPE;
import com.sfit.ctp.thosttraderapi.thosttradeapi;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.lang.reflect.Method;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;

/**
 * CTP(看穿式监管版) 交易 API 的 Delphi 桥接层。
 *
 * 设计要点:
 *  1) CThostFtdcTraderSpi 是 SWIG director 生成的 C++ 抽象类, 必须在 Java 侧继承才能收到回调,
 *     Delphi 无法直接继承 Java 类, 因此把全部 CTP 逻辑收敛到本类, 对 Delphi 只暴露
 *     "若干 String/int 参数的方法 + 一行行文本事件", 避免 Delphi 侧做 JNI/结构体编组。
 *  2) 事件通过 pollEvents() 轮询取走(非阻塞), Delphi 用 TTimer 拉取即可, 无需从 CTP 线程回调 Delphi。
 *  3) 所有 CTP 常量直接引用 SDK 的 thosttradeapi 常量, 不硬编码字符, 保证与 SDK 版本一致。
 */
public class CtpBridge {

    // ---------------------------------------------------------------- 状态
    private CThostFtdcTraderApi api;
    private Spi spi;
    private Context ctx;

    private final LinkedList<String> events = new LinkedList<String>();
    private final Object evLock = new Object();

    private volatile int watchGen = 0;
    private volatile boolean connected = false;
    private volatile boolean loggedIn = false;
    private volatile boolean authenticating = false;

    private volatile int frontId = 0;
    private volatile int sessionId = 0;
    private volatile int maxOrderRef = 0;
    private volatile String tradingDay = "";

    private volatile String brokerId = "";
    private volatile String userId = "";
    private volatile String password = "";
    private volatile String investorId = "";
    private volatile String productInfo = "";
    private volatile String authCode = "";
    private volatile String appId = "";

    private int reqId = 0;

    // ---------------------------------------------------------------- 原生库加载
    // 关键: CThostFtdcTraderApi / CThostFtdcTraderSpi 是 SWIG 生成类, 其 static 初始化块
    // 会调用 native 的 swig_module_init(), 该符号位于 libthosttraderapi_wrap.so。
    // 若此前没有 loadLibrary, 就会出现:
    //   UnsatisfiedLinkError: No implementation found for void ...thosttradeapiJNI.swig_module_init()
    // 顺序必须是 thosttraderapi -> thosttraderapi_wrap (见 SDK README 6.1)。
    private static volatile boolean nativeReady = false;
    private static volatile String nativeReport = "";
    private static volatile boolean mdNativeReady = false;

    public CtpBridge() {
        // 提前加载, 失败也不抛(throws 会变成 ExceptionInInitializerError 打到 Delphi 侧),
        // 只记录原因, 等 start() 时把完整诊断推到日志页。
        try {
            ensureNative();
        } catch (Throwable ignored) {
        }
        // 版本打点: 首次定时器轮询时可见, 用于确认 APK 里实际打包的是哪个桥接版本
        push("[SYS] CtpBridge v2.2-md 已就绪 " + nativeReport);
    }

    private static synchronized boolean ensureNative() {
        if (nativeReady) return true;

        StringBuilder rep = new StringBuilder();
        rep.append("abi=").append(System.getProperty("os.arch")).append(' ');

        String[] libs = {"clientencode", "thosttraderapi", "thosttraderapi_wrap",
                         "thostmduserapi", "thostmduserapi_wrap"};
        for (int i = 0; i < libs.length; i++) {
            try {
                System.loadLibrary(libs[i]);
                rep.append(libs[i]).append("=OK ");
            } catch (Throwable t) {
                rep.append(libs[i]).append("=FAIL[").append(t.getMessage()).append("] ");
                nativeReport = rep.toString();
                // clientencode 只是加密封装模块, 缺了不致命; 后两个缺了就无法交易
                // 行情两个库缺了只影响行情, 不阻塞交易(mdStart 时再报诊断)
                if (i == 1 || i == 2) return false;
            }
        }
        nativeReady = true;
        nativeReport = rep.toString();
        mdNativeReady = nativeReport.contains("thostmduserapi=OK")
                && nativeReport.contains("thostmduserapi_wrap=OK");
        return true;
    }

    /** 加载失败时给出可定位的信息: 架构、APK 里 lib 目录的真实内容。 */
    private String nativeDiagnose() {
        StringBuilder b = new StringBuilder();
        b.append("原生库加载失败: ").append(nativeReport);
        Context c = ctx();
        if (c == null) {
            b.append("\n  取不到 Context, 无法读取 nativeLibraryDir");
            return b.toString();
        }
        try {
            Object ai = c.getClass().getMethod("getApplicationInfo").invoke(c);
            String dir = (String) ai.getClass().getField("nativeLibraryDir").get(ai);
            File d = new File(dir == null ? "" : dir);
            b.append("\n  nativeLibraryDir=").append(dir).append(d.isDirectory() ? " [存在]" : " [不存在]");
            String[] fs = d.list();
            b.append("\n  目录内容=").append(fs == null ? "空" : java.util.Arrays.toString(fs));
        } catch (Throwable t) {
            b.append("\n  读取 nativeLibraryDir 失败: ").append(t);
        }
        b.append("\n  → 若目录里没有 libthosttraderapi_wrap.so, 说明 .so 未打进 APK:")
                .append(" 在 Project > Deployment 把三个 .so 的 Remote Path 设为 library\\lib\\arm64-v8a\\");
        return b.toString();
    }

    /** 供界面/日志显示原生库状态。 */
    public String nativeStatus() {
        return ensureNative() ? ("原生库已加载: " + nativeReport) : nativeDiagnose();
    }

    // ---------------------------------------------------------------- 前置连通性诊断
    private static final int TP_OPEN = 0;
    private static final int TP_REFUSED = 1;
    private static final int TP_TIMEOUT = 2;
    private static final int TP_DNS = 3;
    private static final int TP_OTHER = 4;

    /** 拆出 tcp://host:port 的 host 与 port。 */
    private static String[] splitFront(String front) {
        String addr = front == null ? "" : front.trim();
        if (addr.startsWith("tcp://")) addr = addr.substring(6);
        int idx = addr.lastIndexOf(':');
        String host = idx > 0 ? addr.substring(0, idx) : addr;
        String ps = idx > 0 ? addr.substring(idx + 1) : "0";
        return new String[]{host, ps};
    }

    /**
     * 同步 TCP 探测。刻意区分 ECONNREFUSED 与超时:
     * 前者说明主机在线、只是该端口没有监听(柜台侧状态); 后者才是报文被丢弃(防火墙/白名单)。
     */
    private static int tcpProbe(String host, int port, int timeoutMs, StringBuilder detail) {
        Socket so = new Socket();
        try {
            so.connect(new InetSocketAddress(host, port), timeoutMs);
            return TP_OPEN;
        } catch (java.net.SocketTimeoutException e) {
            detail.append("超时, SYN 无应答");
            return TP_TIMEOUT;
        } catch (java.net.ConnectException e) {
            String m = e.getMessage() == null ? "" : e.getMessage().toLowerCase(Locale.ROOT);
            if (m.contains("refused")) {
                detail.append("ECONNREFUSED, 收到 RST");
                return TP_REFUSED;
            }
            detail.append(String.valueOf(e.getMessage()));
            return TP_OTHER;
        } catch (java.net.UnknownHostException e) {
            detail.append("域名解析失败");
            return TP_DNS;
        } catch (Throwable e) {
            detail.append(String.valueOf(e));
            return TP_OTHER;
        } finally {
            try { so.close(); } catch (Throwable ignored) { }
        }
    }

    /** 把探测结果翻译成「谁的锅 + 该怎么办」。 */
    private void explainProbe(String host, int port, int code, String detail) {
        if (code == TP_OPEN) {
            push("[NET] 前置 " + host + ":" + port + " 端口已开放, 链路可达, 等待 CTP 连接与认证");
        } else if (code == TP_REFUSED) {
            push("[NET] 前置 " + host + ":" + port + " 拒绝连接 (ECONNREFUSED) — 主机在线, 但柜台进程未监听该端口");
            push("[NET] 这是柜台侧状态, 与手机网络无关。常见于: 非交易时段柜台关闭、柜台重启/维护、该端口未对外开放。"
                    + " 若 41313 行情口同样被拒, 基本可确认整台前置未开放, 等开市再连。");
        } else if (code == TP_TIMEOUT) {
            push("[NET] 前置 " + host + ":" + port + " 连接超时 (" + detail + ") — 报文被丢弃, 多为防火墙/安全组未放行。"
                    + " 生产柜台常按白名单开放, 需向期货公司备案本机公网出口 IP; 也可能是工程未勾 INTERNET 权限。");
        } else if (code == TP_DNS) {
            push("[NET] 前置地址无法解析: " + host + " (请直接用 IP, 不要用域名)");
        } else {
            push("[NET] 前置 " + host + ":" + port + " 探测异常 (" + detail + ")");
        }
    }

    /**
     * 未连接时持续监视前置端口。柜台开市后端口一变开放就明确提示,
     * 并且只在「状态发生切换」时写日志, 避免整夜刷屏。
     */
    private void watchFront(final List<String> fronts, final int intervalSec, final int maxMinutes) {
        final int gen = ++watchGen;
        Thread t = new Thread(new Runnable() {
            public void run() {
                int n = fronts.size();
                String[] hosts = new String[n];
                int[] ports = new int[n];
                int[] last = new int[n];
                for (int i = 0; i < n; i++) {
                    String[] hp = splitFront(fronts.get(i));
                    hosts[i] = hp[0];
                    try {
                        ports[i] = Integer.parseInt(hp[1]);
                    } catch (Throwable e) {
                        ports[i] = 0;
                    }
                    last[i] = -1;
                }
                int step = Math.max(5, intervalSec);
                int rounds = Math.max(1, maxMinutes * 60 / step);
                for (int round = 1; round <= rounds; round++) {
                    if (gen != watchGen) return;
                    if (connected || loggedIn) {
                        push("[NET] 前置已连接, 停止端口监视");
                        return;
                    }
                    boolean anyOpen = false;
                    for (int i = 0; i < n; i++) {
                        StringBuilder d = new StringBuilder();
                        int code = tcpProbe(hosts[i], ports[i], 4000, d);
                        if (code != last[i]) {
                            explainProbe(hosts[i], ports[i], code, d.toString());
                            last[i] = code;
                        }
                        if (code == TP_OPEN) anyOpen = true;
                    }
                    if (anyOpen) {
                        try {
                            Thread.sleep(8000);
                        } catch (InterruptedException e) {
                            return;
                        }
                        if (gen != watchGen) return;
                        if (!connected) {
                            push("[SYS] 已有前置端口开放, 但 8 秒内仍未收到 OnFrontConnected。"
                                    + " 请再点一次「连接并登录」重试。");
                        }
                        return;
                    }
                    try {
                        Thread.sleep(step * 1000L);
                    } catch (InterruptedException e) {
                        return;
                    }
                }
                if (gen == watchGen) {
                    push("[NET] 已监视 " + n + " 个前置 " + maxMinutes + " 分钟仍未开放, 停止监视。"
                            + "点「连接并登录」可重新开始。");
                }
            }
        }, "ctp-front-watch");
        t.setDaemon(true);
        t.start();
    }

    // ---------------------------------------------------------------- 事件队列
    private void push(String s) {
        synchronized (evLock) {
            events.add(s);
            if (events.size() > 3000) events.removeFirst();
        }
    }

    /** 取走并清空事件, 供 Delphi 定时器轮询。 */
    public String[] pollEvents() {
        synchronized (evLock) {
            if (events.isEmpty()) return new String[0];
            String[] out = events.toArray(new String[0]);
            events.clear();
            return out;
        }
    }

    private static String f2(double d) {
        return String.format(Locale.US, "%.2f", d);
    }

    private static String s(String v) {
        return v == null ? "" : v;
    }

    private static String err(CThostFtdcRspInfoField e) {
        if (e == null) return "";
        return "[ERR] ErrorID=" + e.getErrorID() + " ErrorMsg=" + s(e.getErrorMsg());
    }

    private static boolean ok(CThostFtdcRspInfoField e) {
        return e == null || e.getErrorID() == 0;
    }

    /** 统一的"未登录"拦截, 顺带告知当前处于哪一步, 便于定位。 */
    private boolean needLogin(String what) {
        if (loggedIn) return false;
        if (connected) {
            push("[SYS] 尚未登录, 不能" + what + " (前置已连接, 请等待认证/登录回报)");
        } else {
            push("[SYS] 尚未登录, 不能" + what + " (前置未连接, 见上方 [NET]/[SYS] 日志)");
        }
        return true;
    }

    /** 通过反射拿 Application Context, 避免把 android 类型暴露给 Delphi。 */
    private Context ctx() {
        if (ctx != null) return ctx;
        try {
            Class<?> at = Class.forName("android.app.ActivityThread");
            Method m = at.getMethod("currentApplication");
            ctx = (Context) m.invoke(null);
        } catch (Throwable t) {
            push("[SYS] 取 Context 失败: " + t);
        }
        return ctx;
    }

    // ---------------------------------------------------------------- 生命周期
    public String apiVersion() {
        if (!ensureNative()) return "unknown";
        try {
            return s(CThostFtdcTraderApi.GetApiVersion());
        } catch (Throwable t) {
            return "unknown";
        }
    }

    public boolean isConnected() { return connected; }
    public boolean isLoggedIn() { return loggedIn; }
    public int getFrontId() { return frontId; }
    public int getSessionId() { return sessionId; }
    public String getTradingDay() { return tradingDay; }

    /**
     * 创建并连接交易前置。
     * @param front      tcp://ip:port
     * @param flowPath   流文件目录, 传空则用应用私有目录
     * @param production true=生产环境, false=评测环境
     */
    public void start(String front, String flowPath, boolean production,
                      String brokerId, String userId, String password, String investorId,
                      String productInfo, String appId, String authCode) {
        connect(splitFronts(front), flowPath, production,
                brokerId, userId, password, investorId, productInfo, appId, authCode);
    }

    /**
     * 真正的连接实现。fronts 可以有多个: CTP 支持在 Init() 之前多次 RegisterFront,
     * 由 API 自己按注册顺序尝试, 某一个前置不可达时自动换下一个(故障切换)。
     */
    private void connect(List<String> fronts, String flowPath, boolean production,
                         String brokerId, String userId, String password, String investorId,
                         String productInfo, String appId, String authCode) {
        this.brokerId = s(brokerId);
        this.userId = s(userId);
        this.password = s(password);
        this.investorId = s(investorId);
        this.productInfo = s(productInfo);
        this.appId = s(appId);
        this.authCode = s(authCode);

        try {
            if (!ensureNative()) {
                push("[SYS] " + nativeDiagnose());
                return;
            }
            if (fronts == null || fronts.isEmpty()) {
                push("[SYS] 没有可用的前置地址, 请检查 INI 里的 Front/Front1/Front2 或界面输入");
                return;
            }
            // 重复点击"连接"时先释放上一次实例, 否则会并存两个 API 与两套流文件
            if (api != null) {
                push("[SYS] 释放上一次的 API 实例后重连");
                try {
                    api.Release();
                } catch (Throwable ignored) {
                }
                api = null;
                spi = null;
                connected = false;
                loggedIn = false;
                authenticating = false;
            }
            if (flowPath == null || flowPath.length() == 0) {
                Context c = ctx();
                if (c != null && c.getFilesDir() != null) {
                    flowPath = new File(c.getFilesDir(), "ctpflow").getAbsolutePath();
                } else {
                    push("[SYS] 取不到应用私有目录, 请在界面填写“流文件目录”");
                    return;
                }
            }
            File f = new File(flowPath);
            if (!f.exists() && !f.mkdirs()) {
                push("[SYS] 无法创建流文件目录: " + flowPath);
            }

            api = CThostFtdcTraderApi.CreateFtdcTraderApi(flowPath, production);
            spi = new Spi(this);
            api.RegisterSpi(spi);
            api.SubscribePrivateTopic(THOST_TE_RESUME_TYPE.THOST_TERT_QUICK);
            api.SubscribePublicTopic(THOST_TE_RESUME_TYPE.THOST_TERT_QUICK);
            // 多前置: Init() 之前可多次 RegisterFront, 由 API 依序尝试并自动切换
            for (int i = 0; i < fronts.size(); i++) {
                api.RegisterFront(fronts.get(i));
            }
            api.Init();
            push("[SYS] API " + apiVersion() + " 已初始化, 流文件=" + flowPath
                    + ", 模式=" + (production ? "生产" : "评测") + ", 前置数=" + fronts.size());
            for (int i = 0; i < fronts.size(); i++) {
                push("[SYS] 前置 #" + (i + 1) + " = " + fronts.get(i));
            }
            push("[SYS] 已调用 Init(), 等待前置回调…");
            // 之后由监视线程按 15 秒一次的节奏探测端口, 柜台开市后会自动提示, 不用反复手点
            watchFront(fronts, 15, 60);
        } catch (Throwable t) {
            push("[SYS] start 异常: " + t);
        }
    }

    /** 把 "tcp://a:1;tcp://b:2" / 逗号 / 换行 拆成多个前置地址, 去掉重复。 */
    private static List<String> splitFronts(String raw) {
        List<String> out = new ArrayList<String>();
        if (raw == null) return out;
        String[] parts = raw.split("[;,\\r\\n]+");
        for (int i = 0; i < parts.length; i++) {
            String v = parts[i].trim();
            if (v.length() == 0) continue;
            if (!v.toLowerCase(Locale.ROOT).startsWith("tcp://")) v = "tcp://" + v;
            boolean dup = false;
            for (int j = 0; j < out.size(); j++) {
                if (out.get(j).equalsIgnoreCase(v)) {
                    dup = true;
                    break;
                }
            }
            if (!dup) out.add(v);
        }
        return out;
    }

    // ---------------------------------------------------------------- INI 配置
    // 配置文件按以下顺序查找(explicit 参数优先):
    //   1) 界面/调用方显式给的路径
    //   2) /sdcard/Android/data/<包名>/files/ctp.ini   ← 推荐, 文件管理器可直接改
    //   3) /data/data/<包名>/files/ctp.ini
    // 都找不到时会在第 2 处生成一份带注释的模板, 打开即可改, 不必重新打包。
    private static final String INI_NAME = "ctp.ini";

    /** 从 INI 解析出来的登录配置。 */
    private static class Config {
        final List<String> fronts = new ArrayList<String>();    // 交易前置
        final List<String> mdFronts = new ArrayList<String>(); // 行情前置(暂只记录, 不订阅)
        String brokerId = "";
        String userId = "";
        String password = "";
        String investorId = "";
        String productInfo = "";
        String appId = "";
        String authCode = "";
        String flowPath = "";
        boolean production = true;
    }

    private Config lastConfig;

    /** 返回当前使用的 INI 路径(不存在则创建模板), 供界面显示。 */
    public String iniPath() {
        File f = resolveIni("");
        return f == null ? "" : f.getAbsolutePath();
    }

    /**
     * 扫描应用目录下的全部 .ini, 用 \n 拼接绝对路径返回, 供界面下拉框选择。
     * 范围: 外部专属目录(/sdcard/Android/data/<包名>/files) + 内部 files 目录。
     * 一个都没有时, 会先在外部目录生成模板再列入 —— 保证首次启动就有可选项。
     */
    public String listIniFiles() {
        LinkedHashSet<String> out = new LinkedHashSet<String>();
        Context c = ctx();
        if (c != null) {
            File ext = null;
            File in = null;
            try {
                ext = c.getExternalFilesDir(null);
            } catch (Throwable ignored) {
            }
            try {
                in = c.getFilesDir();
            } catch (Throwable ignored) {
            }
            File[] dirs = new File[]{ext, in};
            for (int i = 0; i < dirs.length; i++) {
                File d = dirs[i];
                if (d == null || !d.isDirectory()) continue;
                File[] fs = d.listFiles();
                if (fs == null) continue;
                for (int j = 0; j < fs.length; j++) {
                    File f = fs[j];
                    if (f.isFile() && f.getName().toLowerCase(Locale.ROOT).endsWith(".ini")) {
                        out.add(f.getAbsolutePath());
                    }
                }
            }
            if (out.isEmpty()) {
                File d = ext != null ? ext : in;
                if (d != null) {
                    File f = new File(d, INI_NAME);
                    writeTemplate(f);
                    out.add(f.getAbsolutePath());
                }
            }
        }
        StringBuilder b = new StringBuilder();
        for (String p : out) {
            if (b.length() > 0) b.append('\n');
            b.append(p);
        }
        return b.toString();
    }

    private File resolveIni(String explicitPath) {
        if (explicitPath != null && explicitPath.trim().length() > 0) {
            return new File(explicitPath.trim());
        }
        Context c = ctx();
        if (c == null) return null;
        File ext = null;
        File in = null;
        try {
            ext = c.getExternalFilesDir(null);
        } catch (Throwable ignored) {
        }
        try {
            in = c.getFilesDir();
        } catch (Throwable ignored) {
        }
        if (ext != null) {
            File f = new File(ext, INI_NAME);
            if (f.exists()) return f;
        }
        if (in != null) {
            File f = new File(in, INI_NAME);
            if (f.exists()) return f;
        }
        // 都没有: 在外部目录写模板
        File dir = ext != null ? ext : in;
        if (dir == null) return null;
        File f = new File(dir, INI_NAME);
        writeTemplate(f);
        return f;
    }

    private static void writeTemplate(File f) {
        String nl = "\r\n";
        StringBuilder b = new StringBuilder();
        b.append("; ===== CTP 登录配置 =====").append(nl);
        b.append("; 键名不区分大小写; 以 ; 或 # 开头为注释; [Section] 会被忽略。").append(nl);
        b.append("; 多个前置: 用 Front1 / Front2 / Front3 依次写, 或在一行里用 ; 分隔。").append(nl);
        b.append("; CTP 会按顺序尝试, 某个前置不可达时自动切换下一个。").append(nl);
        b.append(nl);
        b.append("[Login]").append(nl);
        b.append("Front1 = tcp://210.5.151.248:41305").append(nl);
        b.append("Front2 =").append(nl);
        b.append("Front3 =").append(nl);
        b.append(nl);
        b.append("BrokerID = 8000").append(nl);
        b.append("UserID = 71171749").append(nl);
        b.append("Password = TopView168").append(nl);
        b.append("InvestorID = 71171749").append(nl);
        b.append("UserProductInfo = TopViewv3958331").append(nl);
        b.append("AuthCode = PRDCTPOYEDWKYOAR").append(nl);
        b.append("AppID = client_TopView_3.0.0.1").append(nl);
        b.append(nl);
        b.append("; 1=生产环境, 0=评测环境").append(nl);
        b.append("Production = 1").append(nl);
        b.append("; 流文件目录, 留空=应用私有目录/ctpflow").append(nl);
        b.append("FlowPath =").append(nl);
        try {
            OutputStreamWriter w = new OutputStreamWriter(new FileOutputStream(f), "UTF-8");
            try {
                w.write(b.toString());
            } finally {
                w.close();
            }
        } catch (Throwable ignored) {
        }
    }

    /** 逐行解析, 同名键保留全部取值(方便重复写 Front=)。 */
    private static Map<String, List<String>> readIni(File f) throws Exception {
        Map<String, List<String>> kv = new LinkedHashMap<String, List<String>>();
        BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
        try {
            String line;
            boolean first = true;
            while ((line = r.readLine()) != null) {
                if (first) {
                    if (line.length() > 0 && line.charAt(0) == '\uFEFF') line = line.substring(1);
                    first = false;
                }
                String t = line.trim();
                if (t.length() == 0 || t.startsWith(";") || t.startsWith("#") || t.startsWith("[")) continue;
                int eq = t.indexOf('=');
                if (eq <= 0) continue;
                String k = t.substring(0, eq).trim().toLowerCase(Locale.ROOT);
                String v = t.substring(eq + 1).trim();
                if (v.length() >= 2 && v.charAt(0) == '"' && v.charAt(v.length() - 1) == '"') {
                    v = v.substring(1, v.length() - 1).trim();
                }
                List<String> list = kv.get(k);
                if (list == null) {
                    list = new ArrayList<String>();
                    kv.put(k, list);
                }
                list.add(v);
            }
        } finally {
            r.close();
        }
        return kv;
    }

    private static String pick(Map<String, List<String>> kv, String key) {
        List<String> v = kv.get(key);
        if (v == null) return "";
        for (int i = v.size() - 1; i >= 0; i--) {
            String x = v.get(i) == null ? "" : v.get(i).trim();
            if (x.length() > 0) return x;
        }
        return "";
    }

    private static Config parseConfig(File f) throws Exception {
        Map<String, List<String>> kv = readIni(f);
        Config c = new Config();
        c.brokerId = pick(kv, "brokerid");
        c.userId = pick(kv, "userid");
        c.password = pick(kv, "password");
        c.investorId = pick(kv, "investorid");
        c.productInfo = pick(kv, "userproductinfo");
        if (c.productInfo.length() == 0) c.productInfo = pick(kv, "userproduct");
        c.appId = pick(kv, "appid");
        c.authCode = pick(kv, "authcode");
        c.flowPath = pick(kv, "flowpath");

        String prod = pick(kv, "production");
        if (prod.length() > 0) {
            prod = prod.toLowerCase(Locale.ROOT);
            c.production = prod.equals("1") || prod.equals("true") || prod.equals("yes") || prod.equals("生产");
        }

        // 前置地址: Front -> Front1..Front9, 顺序即优先级
        TreeMap<Integer, String> ordered = new TreeMap<Integer, String>();
        List<String> plain = kv.get("front");
        if (plain != null) {
            for (int i = 0; i < plain.size(); i++) ordered.put(i, plain.get(i));
        }
        List<String> trad = kv.get("tradfront");
        if (trad != null) {
            for (int i = 0; i < trad.size(); i++) ordered.put(100 + i, trad.get(i));
        }
        for (int i = 1; i <= 9; i++) {
            List<String> v = kv.get("front" + i);
            if (v != null) {
                for (int j = 0; j < v.size(); j++) ordered.put(1000 + i * 10 + j, v.get(j));
            }
        }
        StringBuilder joined = new StringBuilder();
        for (Integer key : ordered.keySet()) {
            String v = ordered.get(key);
            if (v == null || v.trim().length() == 0) continue;
            if (joined.length() > 0) joined.append(';');
            joined.append(v.trim());
        }
        c.fronts.addAll(splitFronts(joined.toString()));

        // 行情前置: MdFront -> MdFront1..MdFront9, 顺序即优先级(只记录, 交易客户端暂不订阅)
        TreeMap<Integer, String> mdOrdered = new TreeMap<Integer, String>();
        List<String> mdPlain = kv.get("mdfront");
        if (mdPlain != null) {
            for (int i = 0; i < mdPlain.size(); i++) mdOrdered.put(i, mdPlain.get(i));
        }
        for (int i = 1; i <= 9; i++) {
            List<String> v = kv.get("mdfront" + i);
            if (v != null) {
                for (int j = 0; j < v.size(); j++) mdOrdered.put(1000 + i * 10 + j, v.get(j));
            }
        }
        for (Integer key : mdOrdered.keySet()) {
            String v = mdOrdered.get(key);
            if (v == null || v.trim().length() == 0) continue;
            c.mdFronts.add(v.trim());
        }
        return c;
    }

    /**
     * 读取 INI 并缓存。返回一行摘要(供界面显示); 失败时返回以 "错误:" 开头的原因。
     * 密码只显示为 ***, 不写进日志。
     */
    public String loadIni(String explicitPath) {
        try {
            File f = resolveIni(explicitPath);
            if (f == null) {
                push("[INI] 取不到应用目录, 无法定位 " + INI_NAME);
                return "错误: 取不到应用目录";
            }
            if (!f.exists()) {
                push("[INI] 配置文件不存在: " + f.getAbsolutePath());
                return "错误: 文件不存在 " + f.getAbsolutePath();
            }
            Config c = parseConfig(f);
            if (c.fronts.isEmpty()) {
                push("[INI] " + f.getAbsolutePath() + " 里没有 Front 地址");
                return "错误: 缺少 Front";
            }
            if (c.brokerId.length() == 0 || c.userId.length() == 0 || c.password.length() == 0) {
                push("[INI] 缺少 BrokerID / UserID / Password");
                return "错误: 缺少 BrokerID/UserID/Password";
            }
            if (c.investorId.length() == 0) c.investorId = c.userId;
            lastConfig = c;

            push("[INI] 已读取 " + f.getAbsolutePath());
            push("[INI] 前置 " + c.fronts.size() + " 个: " + joinFronts(c.fronts));
            push("[INI] BrokerID=" + c.brokerId + " UserID=" + c.userId
                    + " InvestorID=" + c.investorId + " 密码=***"
                    + " AppID=" + c.appId + " 模式=" + (c.production ? "生产" : "评测"));
            return "OK 前置" + c.fronts.size() + "个 " + joinFronts(c.fronts)
                    + " BrokerID=" + c.brokerId + " UserID=" + c.userId;
        } catch (Throwable t) {
            push("[INI] 解析异常: " + t);
            return "错误: " + t;
        }
    }

    private static String joinFronts(List<String> fronts) {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < fronts.size(); i++) {
            if (i > 0) b.append(';');
            b.append(fronts.get(i));
        }
        return b.toString();
    }

    /** 读取 INI 后按其中的参数连接多个前置。 */
    public void startFromIni(String explicitPath) {
        String r = loadIni(explicitPath);
        if (r.startsWith("错误")) {
            push("[SYS] 无法从 INI 启动: " + r);
            return;
        }
        Config c = lastConfig;
        if (c == null) {
            push("[SYS] 配置为空, 未连接");
            return;
        }
        connect(c.fronts, c.flowPath, c.production,
                c.brokerId, c.userId, c.password, c.investorId,
                c.productInfo, c.appId, c.authCode);
    }

    /** 供界面回填输入框: front/brokerid/userid/password/investorid/userproductinfo/appid/authcode/production/flowpath */
    public String getConfig(String key) {
        if (lastConfig == null) {
            loadIni("");
        }
        Config c = lastConfig;
        if (c == null) return "";
        String k = key == null ? "" : key.trim().toLowerCase(Locale.ROOT);
        if (k.equals("front")) return joinFronts(c.fronts);
        if (k.equals("mdfront")) return joinFronts(c.mdFronts);
        if (k.equals("brokerid")) return c.brokerId;
        if (k.equals("userid")) return c.userId;
        if (k.equals("password")) return c.password;
        if (k.equals("investorid")) return c.investorId;
        if (k.equals("userproductinfo")) return c.productInfo;
        if (k.equals("appid")) return c.appId;
        if (k.equals("authcode")) return c.authCode;
        if (k.equals("production")) return c.production ? "1" : "0";
        if (k.equals("flowpath")) return c.flowPath;
        return "";
    }


    /** 认证(有 AppID/AuthCode 时必做)。OnFrontConnected 后自动调用。 */
    private void doAuthenticate() {
        try {
            CThostFtdcReqAuthenticateField f = new CThostFtdcReqAuthenticateField();
            f.setBrokerID(brokerId);
            f.setUserID(userId);
            f.setUserProductInfo(productInfo);
            f.setAppID(appId);
            f.setAuthCode(authCode);
            int id = ++reqId;
            int r = api.ReqAuthenticate(f, id);
            authenticating = true;
            push("[SYS] 发送终端认证 ReqAuthenticate, 返回值=" + r);
        } catch (Throwable t) {
            push("[SYS] ReqAuthenticate 异常: " + t);
        }
    }

    /** 登录。 */
    public void login() {
        try {
            if (api == null) { push("[SYS] 请先连接"); return; }
            Context c = ctx();
            if (c == null) {
                // ReqUserLogin 需要 Context(采集模块用), 拿不到就必然崩在 native 层, 这里提前拦住
                push("[SYS] 登录中止: 未取得 Android Context");
                return;
            }
            CThostFtdcReqUserLoginField f = new CThostFtdcReqUserLoginField();
            f.setBrokerID(brokerId);
            f.setUserID(userId);
            f.setPassword(password);
            f.setUserProductInfo(productInfo);
            int id = ++reqId;
            int r = api.ReqUserLogin(c, f, id);
            push("[SYS] 发送登录 ReqUserLogin, 返回值=" + r);
        } catch (Throwable t) {
            push("[SYS] ReqUserLogin 异常: " + t);
        }
    }

    /** 投资者结算单确认(每个交易日首次交易前必须做一次)。 */
    public void confirmSettlement() {
        try {
            if (needLogin("确认结算单")) return;
            CThostFtdcSettlementInfoConfirmField f = new CThostFtdcSettlementInfoConfirmField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            int id = ++reqId;
            int r = api.ReqSettlementInfoConfirm(f, id);
            push("[SYS] 发送结算单确认, 返回值=" + r);
        } catch (Throwable t) {
            push("[SYS] ReqSettlementInfoConfirm 异常: " + t);
        }
    }

    /**
     * 下单。
     * @param instrument 合约代码, 如 rb2601
     * @param direction  '0'买 '1'卖
     * @param offset     '0'开仓 '1'平仓 '3'平今 '4'平昨
     */
    public void insertOrder(String instrument, String direction, String offset,
                            double price, int volume) {
        try {
            if (needLogin("下单")) return;
            if (instrument == null || instrument.trim().length() == 0) { push("[SYS] 合约不能为空"); return; }
            if (volume <= 0) { push("[SYS] 数量必须大于0"); return; }

            maxOrderRef++;
            String orderRef = String.valueOf(maxOrderRef);

            CThostFtdcInputOrderField f = new CThostFtdcInputOrderField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            f.setUserID(userId);
            f.setInstrumentID(instrument.trim());
            f.setOrderRef(orderRef);
            f.setOrderPriceType(thosttradeapi.THOST_FTDC_OPT_LimitPrice);
            f.setDirection(direction.charAt(0));
            f.setCombOffsetFlag(String.valueOf(offset.charAt(0)));
            f.setCombHedgeFlag(String.valueOf(thosttradeapi.THOST_FTDC_HF_Speculation));
            f.setLimitPrice(price);
            f.setVolumeTotalOriginal(volume);
            f.setTimeCondition(thosttradeapi.THOST_FTDC_TC_GFD);
            f.setVolumeCondition(thosttradeapi.THOST_FTDC_VC_AV);
            f.setMinVolume(1);
            f.setContingentCondition(thosttradeapi.THOST_FTDC_CC_Immediately);
            f.setStopPrice(0.0);
            f.setForceCloseReason(thosttradeapi.THOST_FTDC_FCC_NotForceClose);
            f.setIsAutoSuspend(0);
            f.setUserForceClose(0);
            f.setRequestID(++reqId);

            int r = api.ReqOrderInsert(f, reqId);
            push("[SYS] 报单 " + f.getInstrumentID() + " 方向=" + direction + " 开平=" + offset
                    + " 价格=" + f2(price) + " 数量=" + volume + " OrderRef=" + orderRef
                    + " 返回值=" + r);
            if (r != 0) push("[ERR] 报单被本地拒绝, 返回值=" + r);
        } catch (Throwable t) {
            push("[SYS] ReqOrderInsert 异常: " + t);
        }
    }

    /** 撤单。frontId/sessionId 传 0 则用登录时记录的会话。 */
    public void cancelOrder(String instrument, String orderRef, int frontIdIn, int sessionIdIn) {
        try {
            if (needLogin("撤单")) return;
            CThostFtdcInputOrderActionField f = new CThostFtdcInputOrderActionField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            f.setUserID(userId);
            f.setInstrumentID(instrument == null ? "" : instrument.trim());
            f.setOrderRef(orderRef == null ? "" : orderRef.trim());
            f.setFrontID(frontIdIn == 0 ? frontId : frontIdIn);
            f.setSessionID(sessionIdIn == 0 ? sessionId : sessionIdIn);
            f.setActionFlag(thosttradeapi.THOST_FTDC_AF_Delete);
            f.setRequestID(++reqId);
            int r = api.ReqOrderAction(f, reqId);
            push("[SYS] 撤单 " + f.getInstrumentID() + " OrderRef=" + f.getOrderRef()
                    + " FrontID=" + f.getFrontID() + " SessionID=" + f.getSessionID()
                    + " 返回值=" + r);
        } catch (Throwable t) {
            push("[SYS] ReqOrderAction 异常: " + t);
        }
    }

    public void qryTradingAccount() {
        try {
            if (needLogin("查询资金")) return;
            CThostFtdcQryTradingAccountField f = new CThostFtdcQryTradingAccountField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            api.ReqQryTradingAccount(f, ++reqId);
            push("[SYS] 查询资金...");
        } catch (Throwable t) { push("[SYS] ReqQryTradingAccount 异常: " + t); }
    }

    public void qryInvestorPosition() {
        try {
            if (needLogin("查询持仓")) return;
            CThostFtdcQryInvestorPositionField f = new CThostFtdcQryInvestorPositionField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            api.ReqQryInvestorPosition(f, ++reqId);
            push("[SYS] 查询持仓...");
        } catch (Throwable t) { push("[SYS] ReqQryInvestorPosition 异常: " + t); }
    }

    public void qryOrder() {
        try {
            if (needLogin("查询委托")) return;
            CThostFtdcQryOrderField f = new CThostFtdcQryOrderField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            api.ReqQryOrder(f, ++reqId);
            push("[SYS] 查询委托...");
        } catch (Throwable t) { push("[SYS] ReqQryOrder 异常: " + t); }
    }

    public void qryTrade() {
        try {
            if (needLogin("查询成交")) return;
            CThostFtdcQryTradeField f = new CThostFtdcQryTradeField();
            f.setBrokerID(brokerId);
            f.setInvestorID(investorId);
            api.ReqQryTrade(f, ++reqId);
            push("[SYS] 查询成交...");
        } catch (Throwable t) { push("[SYS] ReqQryTrade 异常: " + t); }
    }

    public void logout() {
        try {
            if (api == null) return;
            CThostFtdcUserLogoutField f = new CThostFtdcUserLogoutField();
            f.setBrokerID(brokerId);
            f.setUserID(userId);
            api.ReqUserLogout(f, ++reqId);
            push("[SYS] 发送登出请求");
        } catch (Throwable t) { push("[SYS] ReqUserLogout 异常: " + t); }
    }

    /** 释放 API(会阻塞等待 Join 返回)。 */
    public void release() {
        try {
            if (mdApi != null) {
                mdApi.Release();
                mdApi = null;
                mdSpi = null;
                mdConnected = false;
                mdLoggedIn = false;
                push("[MD] 行情 API 已释放");
            }
        } catch (Throwable t) { push("[MD] 行情 Release 异常: " + t); }
        try {
            if (api == null) return;
            api.Release();
            api = null;
            spi = null;
            connected = false;
            loggedIn = false;
            push("[SYS] API 已释放");
        } catch (Throwable t) { push("[SYS] Release 异常: " + t); }
    }

    // ---------------------------------------------------------------- 行情(MD) API
    // thostmduserapi 包与 thosttraderapi 包存在同名类(RspInfoField/ReqUserLoginField 等),
    // 因此本段一律使用全限定名, 不 import 行情包, 避免与上方交易包 import 冲突。
    private com.sfit.ctp.thostmduserapi.CThostFtdcMdApi mdApi;
    private MdSpi mdSpi;
    private volatile boolean mdConnected = false;
    private volatile boolean mdLoggedIn = false;
    private final LinkedHashSet<String> mdSubs = new LinkedHashSet<String>(); // 已订阅合约(重连后自动重订)

    public boolean isMdConnected() { return mdConnected; }
    public boolean isMdLoggedIn() { return mdLoggedIn; }

    private static String errMd(com.sfit.ctp.thostmduserapi.CThostFtdcRspInfoField e) {
        if (e == null) return "";
        return "[ERR] ErrorID=" + e.getErrorID() + " ErrorMsg=" + s(e.getErrorMsg());
    }

    private static boolean okMd(com.sfit.ctp.thostmduserapi.CThostFtdcRspInfoField e) {
        return e == null || e.getErrorID() == 0;
    }

    /** CTP 用 DBL_MAX 表示无效价格 → 统一为 "0"。 */
    private static String fmtP(double v) {
        if (v >= 1e300) return "0";
        return String.valueOf(v);
    }

    /** 数量/持仓: 整数时去掉小数点, 显示更干净。 */
    private static String fmtQ(double v) {
        if (v >= 1e300) return "0";
        if (v == Math.floor(v) && Math.abs(v) < 1e15) return String.valueOf((long) v);
        return String.valueOf(v);
    }

    /** "rb2601,cu2508;ih2603 IO2601-C-4500" → 合约数组(保留大小写, 郑商所大小写敏感)。 */
    private static String[] splitInstruments(String raw) {
        LinkedHashSet<String> set = new LinkedHashSet<String>();
        if (raw != null) {
            String[] parts = raw.split("[,，;；\\s]+");
            for (int i = 0; i < parts.length; i++) {
                String v = parts[i].trim();
                if (v.length() > 0) set.add(v);
            }
        }
        return set.toArray(new String[0]);
    }

    /**
     * 启动行情: 注册 INI 里的 MdFront 并 Init。
     * 连接成功后由 MdSpi.OnFrontConnected 自动登录, 登录成功后自动重订 mdSubs 里的合约。
     * Delphi 在交易登录成功后调用一次即可。
     */
    public void mdStart() {
        try {
            if (mdNativeReady == false) {
                ensureNative();
                if (mdNativeReady == false) {
                    push("[MD] 行情原生库未加载: " + nativeReport
                            + " → APK 里缺 libthostmduserapi.so / libthostmduserapi_wrap.so,"
                            + " 请把 MdApi aar 里的 .so 加入部署(library\\lib\\arm64-v8a\\)");
                    return;
                }
            }
            if (mdApi != null) {
                push("[MD] 行情已在运行, 忽略重复启动");
                return;
            }
            if (lastConfig == null) loadIni("");
            List<String> fronts = (lastConfig == null) ? null : lastConfig.mdFronts;
            if (fronts == null || fronts.isEmpty()) {
                push("[MD] INI 里没有行情前置(MdFront/MdFront1..9), 无法启动行情");
                return;
            }
            String mdFlow = "";
            Context c = ctx();
            if (c != null && c.getFilesDir() != null) {
                mdFlow = new File(c.getFilesDir(), "mdflow").getAbsolutePath();
                File f = new File(mdFlow);
                if (!f.exists() && !f.mkdirs()) mdFlow = "";
            }
            mdApi = com.sfit.ctp.thostmduserapi.CThostFtdcMdApi.CreateFtdcMdApi(
                    mdFlow.length() > 0 ? mdFlow : null, false, false);
            mdSpi = new MdSpi(this);
            mdApi.RegisterSpi(mdSpi);
            for (int i = 0; i < fronts.size(); i++) {
                mdApi.RegisterFront(fronts.get(i));
            }
            mdApi.Init();
            push("[MD] 行情 API 已初始化, 前置数=" + fronts.size());
            for (int i = 0; i < fronts.size(); i++) {
                push("[MD] 行情前置 #" + (i + 1) + " = " + fronts.get(i));
            }
        } catch (Throwable t) {
            push("[MD] mdStart 异常: " + t);
        }
    }

    /** 行情登录(由 MdSpi.OnFrontConnected 自动触发, 不需要 Context)。 */
    private void doMdLogin() {
        try {
            com.sfit.ctp.thostmduserapi.CThostFtdcReqUserLoginField f =
                    new com.sfit.ctp.thostmduserapi.CThostFtdcReqUserLoginField();
            f.setBrokerID(brokerId);
            f.setUserID(userId);
            f.setPassword(password);
            f.setUserProductInfo(productInfo);
            int id = ++reqId;
            int r = mdApi.ReqUserLogin(f, id);
            push("[MD] 发送行情登录 ReqUserLogin, 返回值=" + r);
        } catch (Throwable t) {
            push("[MD] 行情登录异常: " + t);
        }
    }

    /** 订阅行情。instruments 支持逗号/分号/空格分隔多个, 保留大小写。 */
    public void mdSubscribe(String instruments) {
        subUnsub(instruments, true);
    }

    /** 退订行情。 */
    public void mdUnsubscribe(String instruments) {
        subUnsub(instruments, false);
    }

    private void subUnsub(String instruments, boolean subscribe) {
        try {
            if (mdApi == null) { push("[MD] 行情未启动, 请先登录交易"); return; }
            if (!mdLoggedIn) { push("[MD] 行情尚未登录, 不能" + (subscribe ? "订阅" : "退订")); return; }
            String[] ids = splitInstruments(instruments);
            if (ids.length == 0) { push("[MD] 未指定合约"); return; }
            int r = subscribe ? mdApi.SubscribeMarketData(ids, ids.length)
                              : mdApi.UnSubscribeMarketData(ids, ids.length);
            for (int i = 0; i < ids.length; i++) {
                if (subscribe) mdSubs.add(ids[i]); else mdSubs.remove(ids[i]);
            }
            push("[MD] " + (subscribe ? "订阅" : "退订") + "请求已发送 "
                    + ids.length + " 个合约, 返回值=" + r);
        } catch (Throwable t) {
            push("[MD] " + (subscribe ? "订阅" : "退订") + "异常: " + t);
        }
    }

    /** 行情回调。注意: OnRtnDepthMarketData 频率高, 事件只做一行文本, 不打日志前缀。 */
    static final class MdSpi extends com.sfit.ctp.thostmduserapi.CThostFtdcMdSpi {
        private final CtpBridge b;

        MdSpi(CtpBridge bridge) { b = bridge; }

        @Override
        public void OnFrontConnected() {
            b.mdConnected = true;
            b.push("[MD] 行情前置已连接, 自动登录");
            b.doMdLogin();
        }

        @Override
        public void OnFrontDisconnected(int nReason) {
            b.mdConnected = false;
            b.mdLoggedIn = false;
            String why;
            switch (nReason) {
                case 0x1001: why = "网络读失败"; break;
                case 0x1002: why = "网络写失败"; break;
                case 0x2001: why = "接收心跳超时"; break;
                case 0x2002: why = "发送心跳失败"; break;
                case 0x2003: why = "收到错误报文"; break;
                default: why = "未知原因"; break;
            }
            b.push("[MD] 行情前置断开, 原因=0x" + Integer.toHexString(nReason) + " (" + why + ")");
        }

        @Override
        public void OnHeartBeatWarning(int nTimeLapse) {
            b.push("[MD] 行情心跳警告, 距上次报文 " + nTimeLapse + " 秒");
        }

        @Override
        public void OnRspUserLogin(com.sfit.ctp.thostmduserapi.CThostFtdcRspUserLoginField pRspUserLogin,
                                   com.sfit.ctp.thostmduserapi.CThostFtdcRspInfoField pRspInfo,
                                   int nRequestID, boolean bIsLast) {
            if (!okMd(pRspInfo)) {
                b.mdLoggedIn = false;
                b.push("[MD] 行情登录失败 " + errMd(pRspInfo));
                return;
            }
            b.mdLoggedIn = true;
            b.push("[MD] 行情登录成功 交易日=" + s(pRspUserLogin.getTradingDay()));
            if (!b.mdSubs.isEmpty()) {
                String[] ids = b.mdSubs.toArray(new String[0]);
                try {
                    int r = b.mdApi.SubscribeMarketData(ids, ids.length);
                    b.push("[MD] 自动重订阅 " + ids.length + " 个合约, 返回值=" + r);
                } catch (Throwable t) {
                    b.push("[MD] 重订阅异常: " + t);
                }
            }
        }

        @Override
        public void OnRspSubMarketData(com.sfit.ctp.thostmduserapi.CThostFtdcSpecificInstrumentField pSpecificInstrument,
                                       com.sfit.ctp.thostmduserapi.CThostFtdcRspInfoField pRspInfo,
                                       int nRequestID, boolean bIsLast) {
            if (!okMd(pRspInfo)) {
                b.push("[MD] 订阅失败 " + errMd(pRspInfo)
                        + " 合约=" + s(pSpecificInstrument == null ? null : pSpecificInstrument.getInstrumentID()));
                return;
            }
            b.push("[MD] 订阅成功 " + s(pSpecificInstrument == null ? null : pSpecificInstrument.getInstrumentID()));
        }

        @Override
        public void OnRspUnSubMarketData(com.sfit.ctp.thostmduserapi.CThostFtdcSpecificInstrumentField pSpecificInstrument,
                                         com.sfit.ctp.thostmduserapi.CThostFtdcRspInfoField pRspInfo,
                                         int nRequestID, boolean bIsLast) {
            if (!okMd(pRspInfo)) {
                b.push("[MD] 退订失败 " + errMd(pRspInfo));
                return;
            }
            b.push("[MD] 退订成功 " + s(pSpecificInstrument == null ? null : pSpecificInstrument.getInstrumentID()));
        }

        @Override
        public void OnRspError(com.sfit.ctp.thostmduserapi.CThostFtdcRspInfoField pRspInfo,
                               int nRequestID, boolean bIsLast) {
            b.push("[MD] 行情 RspError " + errMd(pRspInfo));
        }

        @Override
        public void OnRtnDepthMarketData(com.sfit.ctp.thostmduserapi.CThostFtdcDepthMarketDataField pDepthMarketData) {
            if (pDepthMarketData == null) return;
            StringBuilder sb = new StringBuilder(192);
            sb.append("MDQ|")
              .append(s(pDepthMarketData.getInstrumentID()))
              .append('|').append(fmtP(pDepthMarketData.getLastPrice()))
              .append('|').append(fmtP(pDepthMarketData.getPreClosePrice()))
              .append('|').append(fmtP(pDepthMarketData.getOpenPrice()))
              .append('|').append(fmtP(pDepthMarketData.getHighestPrice()))
              .append('|').append(fmtP(pDepthMarketData.getLowestPrice()))
              .append('|').append(pDepthMarketData.getVolume())
              .append('|').append(fmtP(pDepthMarketData.getBidPrice1()))
              .append('|').append(pDepthMarketData.getBidVolume1())
              .append('|').append(fmtP(pDepthMarketData.getAskPrice1()))
              .append('|').append(pDepthMarketData.getAskVolume1())
              .append('|').append(fmtQ(pDepthMarketData.getOpenInterest()))
              .append('|').append(fmtP(pDepthMarketData.getUpperLimitPrice()))
              .append('|').append(fmtP(pDepthMarketData.getLowerLimitPrice()))
              .append('|').append(s(pDepthMarketData.getUpdateTime()))
              .append('|').append(pDepthMarketData.getUpdateMillisec());
            b.push(sb.toString());
        }
    }

    // ---------------------------------------------------------------- SPI 回调
    static final class Spi extends CThostFtdcTraderSpi {
        private final CtpBridge b;

        Spi(CtpBridge bridge) { b = bridge; }

        @Override
        public void OnFrontConnected() {
            b.connected = true;
            b.push("[SYS] 前置已连接");
            if (b.authCode != null && b.authCode.length() > 0) b.doAuthenticate();
            else b.login();
        }

        @Override
        public void OnFrontDisconnected(int nReason) {
            b.connected = false;
            b.loggedIn = false;
            b.authenticating = false;
            String why;
            switch (nReason) {
                case 0x1001: why = "网络读失败"; break;
                case 0x1002: why = "网络写失败"; break;
                case 0x2001: why = "接收心跳超时"; break;
                case 0x2002: why = "发送心跳失败"; break;
                case 0x2003: why = "收到错误报文"; break;
                default: why = "未知原因"; break;
            }
            b.push("[SYS] 前置连接断开, 原因=0x" + Integer.toHexString(nReason) + " (" + why + ")");
        }

        @Override
        public void OnHeartBeatWarning(int nTimeLapse) {
            b.push("[SYS] 心跳警告, 距上次报文 " + nTimeLapse + " 秒");
        }

        @Override
        public void OnRspAuthenticate(CThostFtdcRspAuthenticateField pRspAuthenticateField,
                                      CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (!ok(pRspInfo)) {
                b.authenticating = false;
                b.push("[SYS] 终端认证失败 " + err(pRspInfo));
                return;
            }
            b.authenticating = false;
            b.push("[SYS] 终端认证成功 AppID=" + s(pRspAuthenticateField == null ? null : pRspAuthenticateField.getAppID()));
            b.login();
        }

        @Override
        public void OnRspUserLogin(CThostFtdcRspUserLoginField pRspUserLogin,
                                   CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (!ok(pRspInfo)) {
                b.loggedIn = false;
                b.push("[SYS] 登录失败 " + err(pRspInfo));
                return;
            }
            b.loggedIn = true;
            b.frontId = pRspUserLogin.getFrontID();
            b.sessionId = pRspUserLogin.getSessionID();
            b.tradingDay = s(pRspUserLogin.getTradingDay());
            try {
                String mor = s(pRspUserLogin.getMaxOrderRef());
                if (mor.length() > 0) b.maxOrderRef = Integer.parseInt(mor.trim());
            } catch (Throwable ignore) { }

            b.push("[SYS] 登录成功 交易日=" + b.tradingDay
                    + " FrontID=" + b.frontId + " SessionID=" + b.sessionId
                    + " MaxOrderRef=" + b.maxOrderRef
                    + " 系统=" + s(pRspUserLogin.getSystemName()));
            b.confirmSettlement();
        }

        @Override
        public void OnRspSettlementInfoConfirm(CThostFtdcSettlementInfoConfirmField pSettlementInfoConfirm,
                                               CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (!ok(pRspInfo)) {
                b.push("[SYS] 结算单确认失败 " + err(pRspInfo));
                return;
            }
            b.push("[SYS] 结算单确认成功, 可以开始交易");
        }

        @Override
        public void OnRspOrderInsert(CThostFtdcInputOrderField pInputOrder,
                                     CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (!ok(pRspInfo)) {
                b.push("[ERR] 报单被拒绝 " + err(pRspInfo)
                        + " 合约=" + s(pInputOrder == null ? null : pInputOrder.getInstrumentID())
                        + " OrderRef=" + s(pInputOrder == null ? null : pInputOrder.getOrderRef()));
            }
        }

        @Override
        public void OnRspOrderAction(CThostFtdcInputOrderActionField pInputOrderAction,
                                     CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (!ok(pRspInfo)) b.push("[ERR] 撤单被拒绝 " + err(pRspInfo));
        }

        @Override
        public void OnRtnOrder(CThostFtdcOrderField pOrder) {
            if (pOrder == null) return;
            b.push("[ORDER] 合约=" + s(pOrder.getInstrumentID())
                    + " OrderRef=" + s(pOrder.getOrderRef())
                    + " 方向=" + pOrder.getDirection()
                    + " 开平=" + s(pOrder.getCombOffsetFlag())
                    + " 价格=" + f2(pOrder.getLimitPrice())
                    + " 已成交/总量=" + pOrder.getVolumeTraded() + "/" + pOrder.getVolumeTotal()
                    + " 状态=" + pOrder.getOrderStatus()
                    + " 系统号=" + s(pOrder.getOrderSysID())
                    + " 时间=" + s(pOrder.getInsertTime())
                    + (s(pOrder.getStatusMsg()).length() > 0 ? " 说明=" + pOrder.getStatusMsg() : ""));
        }

        @Override
        public void OnRtnTrade(CThostFtdcTradeField pTrade) {
            if (pTrade == null) return;
            b.push("[TRADE] 成交 合约=" + s(pTrade.getInstrumentID())
                    + " 方向=" + pTrade.getDirection()
                    + " 开平=" + pTrade.getOffsetFlag()
                    + " 价格=" + f2(pTrade.getPrice())
                    + " 手数=" + pTrade.getVolume()
                    + " 成交号=" + s(pTrade.getTradeID())
                    + " 时间=" + s(pTrade.getTradeTime()));
        }

        @Override
        public void OnRspQryTradingAccount(CThostFtdcTradingAccountField pTradingAccount,
                                           CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (pTradingAccount != null) {
                b.push("[ACCT] 账户=" + s(pTradingAccount.getAccountID())
                        + " 可用=" + f2(pTradingAccount.getAvailable())
                        + " 权益=" + f2(pTradingAccount.getBalance())
                        + " 占用保证金=" + f2(pTradingAccount.getCurrMargin())
                        + " 冻结保证金=" + f2(pTradingAccount.getFrozenMargin())
                        + " 手续费=" + f2(pTradingAccount.getCommission())
                        + " 平仓盈亏=" + f2(pTradingAccount.getCloseProfit())
                        + " 持仓盈亏=" + f2(pTradingAccount.getPositionProfit())
                        + " 风险度≈" + (pTradingAccount.getBalance() == 0 ? "0"
                            : f2(pTradingAccount.getCurrMargin() * 100.0 / pTradingAccount.getBalance()) + "%"));
            }
            if (bIsLast) b.push("[ACCT] --- 资金查询结束 ---");
        }

        @Override
        public void OnRspQryInvestorPosition(CThostFtdcInvestorPositionField pInvestorPosition,
                                             CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (pInvestorPosition != null) {
                b.push("[POS] 合约=" + s(pInvestorPosition.getInstrumentID())
                        + " 方向=" + (pInvestorPosition.getPosiDirection() == thosttradeapi.THOST_FTDC_PD_Long ? "多" : "空")
                        + " 今仓=" + pInvestorPosition.getTodayPosition()
                        + " 昨仓=" + pInvestorPosition.getYdPosition()
                        + " 总持仓=" + pInvestorPosition.getPosition()
                        + " 开仓成本=" + f2(pInvestorPosition.getPositionCost())
                        + " 占用保证金=" + f2(pInvestorPosition.getUseMargin())
                        + " 持仓盈亏=" + f2(pInvestorPosition.getPositionProfit()));
            }
            if (bIsLast) b.push("[POS] --- 持仓查询结束 ---");
        }

        @Override
        public void OnRspQryOrder(CThostFtdcOrderField pOrder,
                                  CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (pOrder != null) {
                b.push("[QORDER] 合约=" + s(pOrder.getInstrumentID())
                        + " OrderRef=" + s(pOrder.getOrderRef())
                        + " 价格=" + f2(pOrder.getLimitPrice())
                        + " 已成交/总量=" + pOrder.getVolumeTraded() + "/" + pOrder.getVolumeTotal()
                        + " 状态=" + pOrder.getOrderStatus()
                        + " 系统号=" + s(pOrder.getOrderSysID()));
            }
            if (bIsLast) b.push("[QORDER] --- 委托查询结束 ---");
        }

        @Override
        public void OnRspQryTrade(CThostFtdcTradeField pTrade,
                                  CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            if (pTrade != null) {
                b.push("[QTRADE] 合约=" + s(pTrade.getInstrumentID())
                        + " 价格=" + f2(pTrade.getPrice())
                        + " 手数=" + pTrade.getVolume()
                        + " 成交号=" + s(pTrade.getTradeID())
                        + " 时间=" + s(pTrade.getTradeTime()));
            }
            if (bIsLast) b.push("[QTRADE] --- 成交查询结束 ---");
        }

        @Override
        public void OnRspError(CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            b.push("[ERR] 错误回报 " + err(pRspInfo) + " (RequestID=" + nRequestID + ")");
        }

        @Override
        public void OnRspUserLogout(CThostFtdcUserLogoutField pUserLogout,
                                    CThostFtdcRspInfoField pRspInfo, int nRequestID, boolean bIsLast) {
            b.loggedIn = false;
            b.push("[SYS] 已登出" + (ok(pRspInfo) ? "" : " " + err(pRspInfo)));
        }
    }
}
