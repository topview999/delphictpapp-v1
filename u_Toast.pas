unit u_Toast;

interface

uses
  System.SysUtils, System.Types, System.Classes
{$IFDEF ANDROID}
    , FMX.Helpers.Android, Androidapi.JNI.app, Androidapi.JNIBridge,
  Androidapi.JNI.JavaTypes, Androidapi.Helpers, Androidapi.JNI.Widget
{$ENDIF}
    ;

type

  TToastLength = record
  const
    ShortToast = 0;
    LongToast = 1;
  end;

  TGravity = record
  const
    AXIS_CLIP = 8;
    AXIS_PULL_AFTER = 4;
    AXIS_PULL_BEFORE = 2;
    AXIS_SPECIFIED = 1;
    AXIS_X_SHIFT = 0;
    AXIS_Y_SHIFT = 4;
    BOTTOM = 80;
    CENTER = 17;
    CENTER_HORIZONTAL = 1;
    CENTER_VERTICAL = 16;
    CLIP_HORIZONTAL = 8;
    CLIP_VERTICAL = 128;
    DISPLAY_CLIP_HORIZONTAL = 16777216;
    DISPLAY_CLIP_VERTICAL = 268435456;
    &END = 8388613;
    FILL = 119;
    FILL_HORIZONTAL = 7;
    FILL_VERTICAL = 112;
    HORIZONTAL_GRAVITY_MASK = 7;
    LEFT = 3;
    NO_GRAVITY = 0;
    RELATIVE_HORIZONTAL_GRAVITY_MASK = 8388615;
    RELATIVE_LAYOUT_DIRECTION = 8388608;
    RIGHT = 5;
    START = 8388611;
    TOP = 48;
    VERTICAL_GRAVITY_MASK = 112;
  end;

/// <summary>
/// 显示安卓原生Toast
/// </summary>
/// <param name="msg">需要显示的内容</param>
/// <param name="duration">显示时间长短</param>
procedure Toast(const msg: string; duration: Integer = TToastLength.ShortToast); overload;

/// <summary>
/// 显示安卓原生Toast
/// </summary>
/// <param name="msg">需要显示的内容</param>
/// <param name="duration">显示时间长短</param>
///  <param name="gravity">显示的位置</param>
///  <param name="xOffset,yOffset">坐标设置</param>
procedure Toast(const msg: string; duration: Integer; gravity: Integer;
  xOffset: Integer; yOffset: Integer); overload;

implementation

procedure Toast(const msg: string; duration: Integer = TToastLength.ShortToast);
begin
{$IFDEF ANDROID}
  CallInUiThread(
    procedure
    begin
      TJToast.JavaClass.makeText(TAndroidHelper.Activity,
        StrToJCharSequence(msg), duration).show;
    end);
{$ENDIF }
end;


procedure Toast(const msg: string; duration: Integer; gravity: Integer;
xOffset: Integer; yOffset: Integer);
{$IFDEF ANDROID}
var
  vToast: JToast;
{$ENDIF}
begin
{$IFDEF ANDROID}
  CallInUiThread(
    procedure
    begin
      vToast := TJToast.JavaClass.makeText(TAndroidHelper.Activity,
        StrToJCharSequence(msg), duration);
      vToast.setGravity(gravity, xOffset, yOffset);
      vToast.show;
    end);
{$ENDIF}
end;

end.

