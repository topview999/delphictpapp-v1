unit MyShareUnit;

interface

uses
  FMX.StdCtrls;

const
  DBKeyConStr = 'CTP_Xin_Le_!^*_168';

type TloginInfo =record
  DEF_FRONT      : string ;//   'tcp://<交易前置地址>:41305';
  DEF_MD         : string ;//   'tcp://<行情前置地址>:41313';
  DEF_BROKER     : string ;//   '<经纪商代码>';
  DEF_USER       : string ;//   '<资金账号>';
  DEF_PASSWORD   : string ;//   '<交易密码>';
  DEF_INVESTOR   : string ;//   '<投资者账号>';
  DEF_PRODUCT    : string ;//   '<客户端产品信息>';
  DEF_APPID      : string ;//   '<AppID>';
  DEF_AUTHCODE   : string ;//   '<授权码>';
end;



var
  backi:Integer =0 ;
  dbFileName :string ;
  LvItemBeDeleteIndex:Integer = -1 ;
implementation


end.
