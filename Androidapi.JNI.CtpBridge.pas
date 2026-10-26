unit Androidapi.JNI.CtpBridge;

{ Delphi 对 com.dctp.bridge.CtpBridge 的 Java 导入单元。
  只暴露 String/Integer/Double/Boolean 参数, 结构体编组全部在 Java 侧完成。 }

interface

uses
  Androidapi.JNIBridge,
  Androidapi.JNI.JavaTypes;

type
  JCtpBridge = interface;

  JCtpBridgeClass = interface(JObjectClass)
    ['{3F0C6A21-8E44-4C1B-9D0E-6A1B2C3D4E01}']
    function init: JCtpBridge; cdecl;
  end;

  [JavaSignature('com/dctp/bridge/CtpBridge')]
  JCtpBridge = interface(JObject)
    ['{3F0C6A21-8E44-4C1B-9D0E-6A1B2C3D4E02}']
    { 事件轮询: 取走并清空回调队列 }
    function pollEvents: TJavaObjectArray<JString>; cdecl;
    function apiVersion: JString; cdecl;
    function isConnected: Boolean; cdecl;
    function isLoggedIn: Boolean; cdecl;
    function getFrontId: Integer; cdecl;
    function getSessionId: Integer; cdecl;
    function getTradingDay: JString; cdecl;
    { 连接 }
    procedure start(front: JString; flowPath: JString; production: Boolean;
      brokerId: JString; userId: JString; password: JString; investorId: JString;
      productInfo: JString; appId: JString; authCode: JString); cdecl;
    { INI 配置: path 传空字符串表示用默认路径(应用外部目录/ctp.ini) }
    function iniPath: JString; cdecl;
    function loadIni(path: JString): JString; cdecl;
    procedure startFromIni(path: JString); cdecl;
    function getConfig(key: JString): JString; cdecl;
    { 扫描应用目录下的全部 .ini, 返回以换行分隔的绝对路径列表 }
    function listIniFiles: JString; cdecl;
    procedure login; cdecl;
    procedure confirmSettlement; cdecl;
    { 行情: mdStart 在交易登录成功后调用一次, 连接/登录/重订阅均在 Java 层自动完成;
      instruments 支持逗号/分号/空格分隔多个, 保留大小写(郑商所敏感) }
    function isMdConnected: Boolean; cdecl;
    function isMdLoggedIn: Boolean; cdecl;
    procedure mdStart; cdecl;
    procedure mdSubscribe(instruments: JString); cdecl;
    procedure mdUnsubscribe(instruments: JString); cdecl;
    { 交易 }
    procedure insertOrder(instrument: JString; direction: JString; offset: JString;
      price: Double; volume: Integer); cdecl;
    procedure cancelOrder(instrument: JString; orderRef: JString;
      frontId: Integer; sessionId: Integer); cdecl;
    { 查询 }
    procedure qryTradingAccount; cdecl;
    procedure qryInvestorPosition; cdecl;
    procedure qryOrder; cdecl;
    procedure qryTrade; cdecl;
    { 收尾 }
    procedure logout; cdecl;
    procedure release; cdecl;
  end;

  TJCtpBridge = class(TJavaGenericImport<JCtpBridgeClass, JCtpBridge>)
  end;

implementation

end.
