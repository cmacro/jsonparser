unit uJsonReaders;

///
///  json 顺序解析读取

interface

uses
  Classes, Windows, SysUtils;

type
  TJSONReaderKind = (
    jrkNone, jrkNull, jrkFalse, jrkTrue, jrkString,
    kNumber, // 不确定 int 还是 float 类型
    jrkObject, jrkArray);

  TJSONReader = record
    JSON: string;
    CurIdx: integer;
    LastIdx: integer;
    TokenIdx: Integer;
    TokenLen : integer;
    procedure Init(const aJSON: string; aIndex, aLen: integer);
    function GetNextChar: char;               // inline;
    function GetNextNonWhiteChar: char;        //inline;
    function CheckNextNonWhiteChar(aChar: char): boolean; //inline;

    function GetToken: string;
    function GetNextString: boolean;
    function GetNextToken: string;
    function GetNext: TJSONReaderKind;
    function ReadJSONObject: boolean;
    function ReadJSONArray: boolean;
    procedure AppendNextStringUnEscape(var str: string);
  end;

implementation

procedure AppendChar(var str: string; chr: Char);
var len: Integer;
begin
  len := length(str);
  SetLength(str,len+1);
  PChar(pointer(str))[len] := chr;
end;

procedure TJSONReader.Init(const aJSON: string; aIndex, aLen: integer);
begin
  JSON := aJSON;
  if aLen > 0 then
    LastIdx := aLen + aIndex
  else
    LastIdx := length(JSON);
  CurIdx := aIndex;
end;

function TJSONReader.GetNextChar: char;
begin
  if CurIdx<=LastIdx then
  begin
    result := JSON[CurIdx];
    inc(CurIdx);
  end
  else
    result := #0;
end;

function TJSONReader.GetNextNonWhiteChar: char;
begin
//  while (CurIdx <= LastIdx) and (JSON[CurIdx] <= ' ') do
//    inc(CurIdx);
//
//  if (CurIdx <= LastIdx) and (JSON[CurIdx] >= ' ') then
//  begin
//    Result := JSON[CurIdx];
//    inc(CurIdx);
//  end
//  else
//    result := #0;

  if CurIdx<=LastIdx then
    repeat
      if JSON[CurIdx]>' ' then
      begin
        result := JSON[CurIdx];
        inc(CurIdx);
        exit;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
  result := #0;
end;

function TJSONReader.CheckNextNonWhiteChar(aChar: char): boolean;
begin
  if CurIdx<=LastIdx then
    repeat
      if JSON[CurIdx]>' ' then
      begin
        result := JSON[CurIdx] = aChar;
        if result then
          inc(CurIdx);
        exit;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
  result := false;
end;

procedure TJSONReader.AppendNextStringUnEscape(var str: string);
var c: char;
    u: string;
    unicode,err: integer;
begin
  repeat
    c := GetNextChar;
    case c of
    #0: exit;
    '"': break;
    '\': begin
      c := GetNextChar;
      case c of
      #0: exit;
      'b': AppendChar(str,#08);
      't': AppendChar(str,#09);
      'n': AppendChar(str,#$0a);
      'f': AppendChar(str,#$0c);
      'r': AppendChar(str,#$0d);
      'u': begin
        u := Copy(JSON,CurIdx,4);
        if length(u)<>4 then
          exit;
        inc(CurIdx,4);
        val('$'+u,unicode,err);
        if err<>0 then
          exit;
        AppendChar(str,char(unicode));
      end;
      else AppendChar(str,c);
      end;
    end;
    else AppendChar(str,c);
    end;
  until false;
end;

function TJSONReader.GetToken: string;
begin
  Result := copy(JSON,TokenIdx,tokenLen);
end;

function TJSONReader.GetNextString: boolean;
var i: integer;
begin
  result := false;
  for i := CurIdx to LastIdx do
    case JSON[i] of
    '"': begin // end of string without escape -> direct copy
      //str := copy(JSON,CurIdx,i-CurIdx);
      TokenIdx := CurIdx; TokenLen := i- CurIdx;
      CurIdx := i+1;
      result := true;
      break;
    end;
    '\':
      begin // need unescaping
        raise Exception.Create('The format is currently not supported');
        //str := copy(JSON,CurIdx,i-CurIdx);
        TokenIdx := CurIdx; TokenLen := i- CurIdx;
        CurIdx := i;
        //AppendNextStringUnEscape(str);
        result := true;
        break;
      end;
    end;
end;

function TJSONReader.GetNextToken: string;
begin
  if GetNextString then
    Result := GetToken
  else result := '';
end;

function TJSONReader.GetNext: TJSONReaderKind;
begin
  result := jrkNone;
  case GetNextNonWhiteChar of
  'n': begin //if copy(JSON,CurIdx,3)='ull' then begin
         inc(CurIdx,3);
         result := jrkNull;
       end;
  'f': begin //if copy(JSON,CurIdx,4)='alse' then begin
         inc(CurIdx,4);
         result := jrkFalse;
       end;
  't': begin //if copy(JSON,CurIdx,3)='rue' then begin
         inc(CurIdx,3);
         result := jrkTrue;
       end;
  '"': if GetNextString then begin
         result := jrkString;
       end;
  '{': if ReadJSONObject then
         result := jrkObject;
  '[': if ReadJSONArray then
         result := jrkArray;
  '-','0'..'9': begin
    TokenIdx := CurIdx-1;
    while true do
      case JSON[CurIdx] of
      '-','+','0'..'9','.','E','e': inc(CurIdx);
      else break;
      end;
    TokenLen := CurIdx-TokenIdx;
    Result := kNumber;
  end;
  end;
end;

function TJSONReader.ReadJSONArray: boolean;
var
  level: Integer;
begin
  TokenIdx := CurIdx - 1;
  level := 0;
  result := false;
  if CurIdx <= LastIdx then
    repeat
      case JSON[CurIdx] of
        '[': inc(level);
        ']': begin
          if level = 0 then
          begin
            inc(CurIdx);
            TokenLen := CurIdx - TokenIdx;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
end;

function TJSONReader.ReadJSONObject: boolean;
var
  level: Integer;
begin
  TokenIdx := CurIdx - 1;
  level := 0;
  result := false;
  if CurIdx <= LastIdx then
    repeat
      case JSON[CurIdx] of
        '{': inc(level);
        '}': begin
          if level = 0 then
          begin
            inc(CurIdx);
            TokenLen := CurIdx - TokenIdx;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
end;

end.
