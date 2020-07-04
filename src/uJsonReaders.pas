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
    Index: integer;
    Len: integer;
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
    Len := aLen + aIndex
  else
    Len := length(JSON);
  Index := aIndex;
end;

function TJSONReader.GetNextChar: char;
begin
  if Index<=Len then
  begin
    result := JSON[Index];
    inc(Index);
  end
  else
    result := #0;
end;

function TJSONReader.GetNextNonWhiteChar: char;
begin
  if Index<=Len then
    repeat
      if JSON[Index]>' ' then
      begin
        result := JSON[Index];
        inc(Index);
        exit;
      end;
      inc(Index);
    until Index>Len;
  result := #0;
end;

function TJSONReader.CheckNextNonWhiteChar(aChar: char): boolean;
begin
  if Index<=Len then
    repeat
      if JSON[Index]>' ' then
      begin
        result := JSON[Index] = aChar;
        if result then
          inc(Index);
        exit;
      end;
      inc(Index);
    until Index>Len;
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
        u := Copy(JSON,Index,4);
        if length(u)<>4 then
          exit;
        inc(Index,4);
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
  for i := Index to Len do
    case JSON[i] of
    '"': begin // end of string without escape -> direct copy
      //str := copy(JSON,Index,i-Index);
      TokenIdx := Index; TokenLen := i- Index;
      Index := i+1;
      result := true;
      break;
    end;
    '\':
      begin // need unescaping
        raise Exception.Create('The format is currently not supported');
        //str := copy(JSON,Index,i-Index);
        TokenIdx := Index; TokenLen := i- Index;
        Index := i;
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
  'n': begin //if copy(JSON,Index,3)='ull' then begin
         inc(Index,3);
         result := jrkNull;
       end;
  'f': begin //if copy(JSON,Index,4)='alse' then begin
         inc(Index,4);
         result := jrkFalse;
       end;
  't': begin //if copy(JSON,Index,3)='rue' then begin
         inc(Index,3);
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
    TokenIdx := Index-1;
    while true do
      case JSON[Index] of
      '-','+','0'..'9','.','E','e': inc(Index);
      else break;
      end;
    TokenLen := Index-TokenIdx;
    Result := kNumber;
  end;
  end;
end;

function TJSONReader.ReadJSONArray: boolean;
var
  level: Integer;
begin
  TokenIdx := Index - 1;
  level := 0;
  result := false;
  if Index <= Len then
    repeat
      case JSON[Index] of
        '[': inc(level);
        ']': begin
          if level = 0 then
          begin
            inc(Index);
            TokenLen := Index - TokenIdx;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(Index);
    until Index>Len;
end;

function TJSONReader.ReadJSONObject: boolean;
var
  level: Integer;
begin
  TokenIdx := Index - 1;
  level := 0;
  result := false;
  if Index <= Len then
    repeat
      case JSON[Index] of
        '{': inc(level);
        '}': begin
          if level = 0 then
          begin
            inc(Index);
            TokenLen := Index - TokenIdx;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(Index);
    until Index>Len;
end;

end.
