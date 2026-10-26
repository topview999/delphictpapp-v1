program CtpApp;
{ 海通期货 CTP 安卓交易客户端
  Delphi 11.3 Alexandria / FMX / Android 64-bit
  窗体无 .fmx 资源, 界面在 MainUnit.TMainForm.Create 中用代码创建。 }
uses
  System.StartUpCopy,
  FMX.Forms,
  Androidapi.JNI.CtpBridge in 'Androidapi.JNI.CtpBridge.pas',
  MainFmxU in 'MainFmxU.pas' {MainFmx},
  MyShareUnit in 'MyShareUnit.pas',
  u_Toast in 'u_Toast.pas',
  MyShareProcedure in 'MyShareProcedure.pas';

{$R *.res}
begin
  Application.Initialize;
  Application.CreateForm(TMainFmx, MainFmx);
  Application.Run;
end.
