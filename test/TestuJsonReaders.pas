﻿unit TestuJsonReaders;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  TestFramework, Classes, SysUtils, uJsonReaders, Windows, JsonDataObjects;

type
  TTestTJSONPCharReader = class(TTestCase)
  private
    function CheckObjectJson(s: PChar; len: LongInt; var msg: string): boolean;
    function CheckArrayJson(s: PChar; len: LongInt; var msg: string): boolean;
    function CheckNodeItem(k: TJSONReaderKind; const sfieldName: string; var r:
        TJSONReader; cJsonObj: TJsonObject; var msg: string): boolean;
  public
    function CheckCompareData(const data: string; var msg: string): Boolean;
    function CheckCompareFile(const fn: string; var msg: string): Boolean;
  published
    procedure TestEatchData;
    procedure TestDefault;
    procedure TestReader;
    procedure TestBigFile;
    procedure Testfails;
    procedure TestFile;

  end;

function kToBool(k: TJSONReaderKind): boolean;




implementation

uses
  TypInfo;

  function GetIndent(l: integer): string;
  var I: Integer;
  begin
    l := l * 2;
    SetLength(Result, l);
    for I := 1 to l do
      Result[i] := ' ';
  end;



procedure ReadFileData(const fn: string; var data: string);
var
  cFile: TStringStream;
begin
  cFile := TStringStream.Create('', TEncoding.UTF8);
  try
    cFile.LoadFromFile(fn);
    data := cFile.DataString;
  finally
    cFile.Free;
  end;
end;



function JsonToStr(const src: string): string;
begin

end;

function kToBool(k: TJSONReaderKind): boolean;
begin
  if k = jrkFalse then result := False
  else result := True;
end;


function TTestTJSONPCharReader.CheckArrayJson(s: PChar; len: LongInt; var msg:
    string): boolean;
var
  bSucc: Boolean;
  c: Char;
  iIdx: Integer;
  k: TJSONReaderKind;
  r: TJSONReader;
  cJsonObj: TJsonArray;
  Current: Integer;
  jt: TJsonDataType;
  sNewData: string;

  procedure SetMsg(const s: string);
  begin
    msg := format('Index: %d -> %d %s', [Current, r.Curr - r.JSON, s]);
  end;

begin
 Result := False;
 if len <= 0 then
  len := length(s);
  r.init(s,len);
  k := r.GetDataType;
  if k <> jrkArray then
    Exit;

  cJsonObj := TJsonArray.Create;
  try
    SetString(sNewData, s, len);
    cJsonObj.FromJSON(sNewData);

    Current := -1;
    while True do
    begin
      inc(Current);
      iIdx := r.Curr - r.JSON;
      k := r.GetNext;
      jt := jdtNone;
      if k <> jrkNone then
        jt := cJsonObj.Types[Current];

      case k of
        jrkNone: begin
                  if (cJsonObj.Count = Current) then Break;
                  SetMsg('field not value'); Exit;
                end;
        jrkNull: begin
                  if ((jt = jdtObject) and (cJsonObj.Items[Current].ObjectValue <> nil)) then
                  begin
                    SetMsg('Field types None are inconsistent'); Exit;
                  end;
                  if not (jt  in [jdtObject,jdtNone]) then
                  begin
                    SetMsg('Field types None are inconsistent'); Exit;
                  end;
                 end;
        jrkFalse,
        jrkTrue :begin
                  if jt <> jdtBool then
                  begin
                    SetMsg('Field types boolean are inconsistent'); Exit;
                  end;
                  if cJsonObj.B[Current] <> kToBool(k) then
                  begin
                    SetMsg('Field value are inconsistent'); Exit;
                  end;
                 end ;
        jrkString: begin
                  if jt <> jdtString then
                  begin
                    SetMsg('Field types string are inconsistent'); Exit;
                  end;
                  if not SameText(r.GetToStrToken, cJsonObj.S[Current]) then
                  begin
                    SetMsg('Field value '+ cJsonObj.S[Current] +' are inconsistent'); Exit;
                  end;
                 end;
        jrkNumber:  begin
                  if not (jt in [jdtInt, jdtLong, jdtULong, jdtFloat]) then
                  begin
                    SetMsg('Field types kNumber are inconsistent'); Exit;
                  end;
                  if not SameText(r.GetToken, cJsonObj.S[Current]) then
                  begin
                    bSucc := False;
                    case jt of
                      jdtInt    : bSucc := r.AsInt = cJsonObj.I[Current];
                      jdtLong   : bSucc := r.AsInt64 = cJsonObj.L[Current];
                      jdtULong  : bSucc := r.AsUInt64 = cJsonObj.U[Current];
                      jdtFloat  : bSucc := SameStr(FloatToStr(r.AsFloat), cJsonObj.S[Current]);
                    end;
                    if not bSucc then
                    begin
                      SetMsg('Field value '+ cJsonObj.S[Current] +' are inconsistent');
                      Exit;
                    end;
                  end;
                 end;
        jrkObject: begin
                  if cJsonObj.Types[Current] <> jdtObject then
                  begin
                    SetMsg('Field types string are inconsistent'); Exit;
                  end;
                  if not CheckObjectJson(r.Token, r.TokenLen, msg) then
                  begin
                    msg := format('Index: %d, Current: %d %s', [iIdx, Current, msg]); // InttoStr() +'  ' + msg;
                    Exit;
                  end;
                 end;
        jrkArray: begin
                  if cJsonObj.Types[Current] <> jdtArray then
                  begin
                    SetMsg('Field types string are inconsistent'); Exit;
                  end;
                  if not CheckArrayJson(r.Token, r.TokenLen, msg) then
                  begin
                    msg := format('Index: %d, Current: %d %s', [iIdx, Current, msg]);
                    Exit;
                  end;
                 end;
        else
        begin
          SetMsg('unknown type'); Exit;
        end;
      end;

      c := r.GetNextNonWhiteChar;
      if not ((c = ',') or (c = #0) or (c = ']')) then
      begin
        SetMsg('the value is not over');
        Exit;
      end;

      if (c = #0) or (c = ']') then
        Break;
    end;
  finally
    cJsonObj.Free;
  end;

  Result := True;

end;

function TTestTJSONPCharReader.CheckCompareData(const data: string; var msg:
    string): Boolean;
var
  k: TJSONReaderKind;
  rReader: TJSONReader;
begin
  rReader.Init(PChar(data), -1);
  k := rReader.GetDataType;
  if k = jrkObject then
    Result := CheckObjectJson(PChar(data), -1, msg)
  else if k = jrkArray then
    Result := CheckArrayJson(PChar(data), -1, msg)
  else
  begin
    msg := 'unknown value';
    Result := False;
  end;
end;

function TTestTJSONPCharReader.CheckCompareFile(const fn: string; var msg:
    string): Boolean;
var
  s: string;
begin
  ReadFileData(fn, s);
  Result := CheckCompareData(s, msg);
end;

function TTestTJSONPCharReader.CheckNodeItem(k: TJSONReaderKind; const
    sfieldName: string; var r: TJSONReader; cJsonObj: TJsonObject; var
    msg: string): boolean;

  procedure SetMsg(const s: string);
  var
    d: string;
  begin
    //if iidx < r.CurIdx then
    SetString(d, r.Curr, 10);// := Copy(r.JSON, iIdx, r.CurIdx - iIdx)
    //else  d := '';
    msg := format('Index: %s', [d]);
  end;
var
  bSucc: Boolean;
  jt: TJsonDataType;
begin
  Result := False;
  jt := cJsonObj.Types[sFieldName];
  case k of
    jrkNone: begin  SetMsg('field not value'); Exit; end;
    jrkNull: begin
              if (jt = jdtObject) and (cJsonObj.O[sFieldName] = nil ) then
              begin
                Result := true;
                Exit;
              end;

              if cJsonObj.Types[sFieldName] <> jdtNone then
              begin
                SetMsg('Field types None are inconsistent'); Exit;
              end;

             end;
    jrkFalse,
    jrkTrue :begin
              if cJsonObj.Types[sFieldName] <> jdtBool then
              begin
                SetMsg('Field types boolean are inconsistent'); Exit;
              end;
              if cJsonObj.B[sFieldName] <> kToBool(k) then
              begin
                SetMsg('Field value are inconsistent'); Exit;
              end;
             end ;
    jrkString: begin
              if cJsonObj.Types[sFieldName] <> jdtString then
              begin
                SetMsg('Field types string are inconsistent'); Exit;
              end;
              if not SameText(r.GetToStrToken, cJsonObj.S[sFieldName]) then
              begin
                SetMsg('Field value '+ cJsonObj.S[sFieldName] +' are inconsistent'); Exit;
              end;
             end;
    jrkNumber:  begin
              if not (cJsonObj.Types[sFieldName] in [jdtInt, jdtLong, jdtULong, jdtFloat]) then
              begin
                SetMsg('Field types kNumber are inconsistent'); Exit;
              end;

              if not SameText(r.GetToken, cJsonObj.S[sFieldName]) then
              begin
                bSucc := False;
                case jt of
                  jdtInt    : bSucc := r.AsInt = cJsonObj.I[sfieldName];
                  jdtLong   : bSucc := r.AsInt64 = cJsonObj.L[sfieldName];
                  jdtULong  : bSucc := r.AsUInt64 = cJsonObj.U[sfieldName];
                  jdtFloat  : bSucc := SameStr(FloatToStr(r.AsFloat), cJsonObj.S[sfieldName]);
                end;
                if not bSucc then
                begin
                  SetMsg('Field value '+ cJsonObj.S[sFieldName] +' are inconsistent'); Exit;
                end;
              end;
             end;
    jrkObject: begin
              if cJsonObj.Types[sFieldName] <> jdtObject then
              begin
                SetMsg('Field types string are inconsistent'); Exit;
              end;
              if not CheckObjectJson(r.Token, r.TokenLen, msg) then
                Exit;
             end;
    jrkArray: begin
              if cJsonObj.Types[sFieldName] <> jdtArray then
              begin
                SetMsg('Field types string are inconsistent'); Exit;
              end;
              if not CheckArrayJson(r.Token, r.TokenLen, msg) then
                Exit;
             end;
    else
    begin
      SetMsg('unknown type'); Exit;
    end;
  end;

  Result := True;

end;

function TTestTJSONPCharReader.CheckObjectJson(s: PChar; len: LongInt; var msg:
    string): boolean;
var
  c: Char;
  cJsonObj: TJsonObject;
  k: TJSONReaderKind;
  rReader: TJSONReader;
  sFieldName: string;
  sNewData: string;

  procedure SetMsg(const s: string);
  var
    d: string;
  begin
    SetString(d, rReader.Curr, 10);
    msg := Format(' fieldname: %s Index:  %s', [sFieldName, d]);
  end;

begin
  Result := False;
  if len <= 0 then
    len := length(s);

  rReader.Init(s, len);
  k := rReader.GetDataType;
  if k <> jrkObject then
    Exit;

  sFieldName := '';
  cJsonObj := TJsonObject.Create;
  try
    SetString(sNewData, s, len);
    cJsonObj.FromJSON(sNewData);

    while True do
    begin
      k := rReader.GetNext;
      if (k = jrkNone) and (cJsonObj.Count = 0) then
        Break;

      if k = jrkNone then
      begin
        SetMsg('read object error ' + sNewData);
        Exit;
      end;

      if k <> jrkString then
      begin
        SetMsg('read field name');
        Exit;
      end;
      if rReader.GetNextNonWhiteChar <> ':' then
      begin
        SetMsg('The field is not over');
        Exit;
      end;

      sFieldName := rReader.GetToStrToken;
      k :=  rReader.GetNext;
      if not CheckNodeItem(k, sFieldName, rReader, cJsonObj, msg) then
        Exit;

      c := rReader.GetNextNonWhiteChar;
      if not ((c = ',') or (c = #0) or (c = '}')) then
      begin
        SetMsg('the value is not over');
        Exit;
      end;

      if (c = #0) or (c = '}') then
      begin
        Break;
      end;

    end;
  finally
    cJsonObj.Free;
  end;

  Result := True;

end;

{ TTestTJSONPCharReader }

procedure TTestTJSONPCharReader.TestBigFile;

begin

//  cStr := TStringStream.Create('', TEncoding.UTF8);
//  try
//    cStr.LoadFromFile('.\data\bpProducts.json');
//    LChars := TEncoding.UTF8.GetChars(cStr.Bytes);
//  finally
//    cStr.Free;
//  end;


    //s := cStr.DataString; // cStr.DataString TStringBuilder.Create;

//    r.Init(PChar(LChars), -1);
//    r.GetDataType;



//  Check(CheckCompareFile('.\data\bpProducts.json', msg), 'parser bpProducts.json file：' + msg);
//  iTick := GetTickCount - iTick;
//  Writeln('   tickcount :' + inttostr(iTick));

end;

procedure TTestTJSONPCharReader.TestDefault;
var
  parser: TJSONReader;
  s: string;

  procedure SetParserStr(const d: string);
  begin
    s := d;
    parser.Init(PChar(s), -1);
  end;

begin
  SetParserStr('{}');
  Check(parser.GetNextNonWhiteChar = '{', 'Is empty object');
  Check(parser.GetNext = jrkNone, 'Is empty object');

  SetParserStr('{"hex": "\u4e2d\u6587\u6d4b\u8bd5", "abc": 1}');
  check(parser.GetDataType = jrkObject, 'Read Json data type, should be Object');
  check(parser.GetNext = jrkString, 'Read attribute name');
  Check(parser.GetToken = 'hex');

  Check(parser.GetNextNonWhiteChar = ':');
  check(parser.GetNext = jrkString);
  Check(parser.GetToken = '\u4e2d\u6587\u6d4b\u8bd5', 'read token err');
  Check(parser.AsStr = '中文测试');

  SetParserStr('{"hex": "\u4e2d\u6587\u6d4b\u8bd5", "abc": 1}');
  parser.GetDataType;
  Check(parser.GetNextOf('abc') = jrkNumber);
  Check(parser.AsInt = 1);

  SetParserStr('{"str": "str", "int": 123, "float": 12.3, "bool": true}');
  Check(parser.GetDataType = jrkObject);
  parser.EatchObjID(function (const AID: string; const AToken: TTokenData): boolean
  begin
    Result := True;
    if aid = 'str' then
    begin
      Check(atoken.Kind = jrkString);
      check(TokenToStr(atoken) = 'str');
    end
    else if aid = 'int' then
    begin
      Check(atoken.Kind = jrkNumber);
      check(parser.AsInt = 123);
    end;
  end);

  SetParserStr('{"str": "''str[]{}\"", "data": 123}');
  Check(parser.GetDataType = jrkObject);
  Check(parser.GetNext = jrkString);
  check(parser.GetNextNonWhiteChar = ':');
  Check(parser.GetNext = jrkString);
  Check(parser.AsStr = '''str[]{}"');
  check(parser.GetNextNonWhiteChar = ',');
  Check(parser.GetNext = jrkString);
  Check(parser.AsStr = 'data');
end;

procedure TTestTJSONPCharReader.TestEatchData;
var
  sData: string;
  reader: TJSONReader;
begin
  Exit;
  ReadFileData('.\passes\1.json', sData);
  reader.Init(PChar(sData), -1);
  Check(reader.GetDataType = jrkArray);
  reader.EatchArray(function (index: Integer; const AToken: TTokenData): boolean
  begin
    Result := True;
    writeln(GetEnumName(TypeInfo(TJSONReaderKind),Ord(AToken.Kind)));
  end);

  ReadFileData('.\passes\3.json', sData);
  reader.Init(PChar(sData), -1);
  Check(reader.GetDataType = jrkObject);
  reader.EatchObjID(function (const AID: string; const AToken: TTokenData): boolean
  begin
    Result := True;
    write(AID);
    write(' = ');
    writeln('type:' + GetEnumName(TypeInfo(TJSONReaderKind),Ord(AToken.Kind)));
  end);


end;

procedure TTestTJSONPCharReader.Testfails;
var
  sData: string;
  r: TJSONReader;
  function readerinit(const s: string): TJSONReaderKind;
  begin
    sData := s;
    r.Init(PChar(sData), -1);
    result := r.GetDataType;
  end;

  function readKey: string;
  begin
    Result := '';
    if r.GetNext = jrkString then
    begin
      Result := r.AsStr;
      if r.GetNextNonWhiteChar <> ':' then
        Result := '';
    end;
  end;

begin
  writeln('Test Fails Data!');

  Check(readerinit('["Unclosed array"') = jrkArray);
  Check(r.GetNext = jrkString);
  Check(r.GetNextNonWhiteChar = #0);
  r.reset;
  r.EatchArray(function (index:Integer; const AToken: TTokenData): boolean
  begin
    Result := True;
    Check(index < 1, 'Unclosed array'); //
  end);



  Check(readerinit('{unquoted_key: "keys must be quoted"}') = jrkObject, 'unquoted_key');
  Check(r.GetNext = jrkNone, 'unquoted_key');

  Check(readerinit('["extra comma",]') = jrkArray, 'extra comma');
  Check(r.GetNext = jrkString, 'extra comma');
  Check(r.GetNextNonWhiteChar = ',', 'extra comma');
  Check(r.GetNext = jrkNone, 'extra comma');

  Check(readerinit('["double extra comma",,]') = jrkArray, 'double extra comma');
  Check(r.GetNext = jrkString, 'double extra comma');
  Check(r.GetNextNonWhiteChar = ',', 'double extra comma');
  Check(r.GetNext = jrkNone, 'double extra comma');

  Check(readerinit('[   , "<-- missing value"]') = jrkArray);
  Check(r.GetNext = jrkNone);

  Check(readerinit('["Comma after the close"],') = jrkArray, 'Comma after the close');
  Check(r.GetNext = jrkString, 'Comma after the close');
  Check(r.GetNextNonWhiteChar = ']', 'Comma after the close');
  Check(r.GetNext = jrkNone, 'Comma after the close'); // 此处允许无错误
  r.reset;
  r.EatchArray(function (index:Integer; const AToken: TTokenData): boolean
  begin
    Result := True;
    Check(index < 1, 'Comma after the close'); //
  end);

  Check(readerinit('["Extra close"]]') = jrkarray, 'Extra close');
  Check(r.GetNext = jrkString, 'Extra close');
  Check(r.GetNextNonWhiteChar = ']', 'Extra close');
  Check(r.GetNext = jrkNone, 'Extra close'); // 此处允许无错误
  r.reset;
  r.EatchArray(function (index:Integer; const AToken: TTokenData): boolean
  begin
    Result := True;
    Check(index < 1, 'Extra close'); //
  end);

  Check(readerinit('{"Extra comma": true,}') = jrkObject);
  Check(r.GetNext = jrkString);
  Check(r.GetNextNonWhiteChar = ':');
  Check(r.GetNext = jrkTrue);
  Check(r.GetNextNonWhiteChar = ',');
  Check(r.GetNext = jrkNone, 'Extra comma');
  r.reset;
  r.EatchObjID(function (const AID:string; const AToken: TTokenData): boolean
  begin
    Result := True;
    Check(AID = 'Extra comma' , 'Extra comma'); // 第二个不会被读取
  end);

  Check(readerinit('{"Extra value after close": true} "misplaced quoted value"') = jrkObject, 'Extra value after close');
  Check(r.GetNext = jrkString, 'Extra value after close');
  Check(r.GetNextNonWhiteChar = ':', 'Extra value after close');
  Check(r.GetNext = jrkTrue, 'Extra value after close');
  Check(r.GetNextNonWhiteChar = '}', 'Extra value after close');
  r.reset;
  r.EatchObjID(function (const AID:string; const AToken: TTokenData): boolean
  begin
    Result := True;
    Check(AID = 'Extra value after close' , 'Extra value after close'); // 第二个不会被读取
  end);

  Check(readerinit('{"Illegal expression": 1 + 2}') = jrkObject, 'Illegal expression');
  Check(r.GetNext = jrkString, 'Illegal expression');
  Check(r.GetNextNonWhiteChar = ':', 'Illegal expression');
  Check(r.GetNext = jrkNumber, 'Illegal expression');
  Check(r.GetNextNonWhiteChar = '+', 'Illegal expression');
  r.reset;
  r.EatchObjID(function (const AID: string; const AToken: TTokenData): boolean
  begin
    check(AID = 'Illegal expression', 'Illegal expression'); // 只有一个Key
    check(AToken.Kind = jrkNumber, 'Illegal expression');
  end);


  Check(readerinit('{"Illegal invocation": alert()}') = jrkObject, 'Illegal invocation');
  Check(r.GetNext = jrkString, 'Illegal invocation');
  Check(r.GetNextNonWhiteChar = ':', 'Illegal invocation');
  Check(r.GetNext = jrkNone, 'Illegal invocation');

  Check(readerinit('{"Numbers cannot have leading zeroes": 013}') = jrkObject, 'Numbers cannot have leading zeroes');
  Check(readKey = 'Numbers cannot have leading zeroes', 'Numbers cannot have leading zeroes');
  Check(r.GetNext = jrkNumber, 'Numbers cannot have leading zeroes');
  Check(r.AsInt = 13, 'Numbers cannot have leading zeroes');

  Check(readerinit('{"Numbers cannot be hex": 0x14}') = jrkObject, 'Numbers cannot be hex');
  Check(readKey = 'Numbers cannot be hex', 'Numbers cannot be hex');
  Check(r.GetNext = jrkNumber, 'Numbers cannot be hex');
  Check(r.GetNext = jrkNone, 'Numbers cannot be hex');



  Check(readerinit('{"resultParamList":{},"dataList":[["[StringConcat]{}"]],"fieldTypeList":[["abc"]]"}') = jrkObject);
  Check(readKey = 'resultParamList');
  Check(r.GetNext = jrkObject);
  Check(r.GetNextNonWhiteChar = ',');
  Check(readKey = 'dataList');
  Check(r.GetNext = jrkArray);
  Check(r.AsStr = '[["[StringConcat]{}"]]');
  Check(r.GetNextNonWhiteChar = ',');
  Check(readKey = 'fieldTypeList');
  Check(r.GetNext = jrkArray);
  Check(r.AsStr = '[["abc"]]');





//  check(r.GetDataType = jrkObject);



//  Check(readerinit('') = jrkObject);







end;

procedure TTestTJSONPCharReader.TestFile;
var
  r: TJSONReader;
  s: string;
  sField: string;
  split: Char;

  function readKey: string;
  begin
    Result := '';
    if r.GetNext = jrkString then
    begin
      Result := r.AsStr;
      if r.GetNextNonWhiteChar <> ':' then
        Result := '';
    end;
  end;
begin
  ReadFileData('.\data\err.json', s);
  r.Init(PChar(s), -1);
  Check(r.GetDataType = jrkObject);
//  Check(readKey = msg);
  check(r.GetNextOf('ReturnDataList')= jrkObject);



end;

procedure TTestTJSONPCharReader.TestReader;
var
  iTick: Cardinal;
  msg: string;
begin
  Writeln(' TJSONReader passes json file');
  iTick := GetTickCount;
  Check(CheckCompareFile('.\passes\1.json', msg), 'parser passes 1.json file：' + msg);
  Check(CheckCompareFile('.\passes\2.json', msg), 'parser passes 2.json file：' + msg);
  Check(CheckCompareFile('.\passes\3.json', msg), 'parser passes 3.json file：' + msg);
  iTick := GetTickCount - iTick;
  Writeln('   tickcount :' + inttostr(iTick));

end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TTestTJSONPCharReader.Suite);
end.

