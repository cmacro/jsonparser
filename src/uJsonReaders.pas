unit uJsonReaders;

///
///  json 顺序解析读取

interface

uses
  Classes, Windows, SysUtils;

type
  TJSONParserKind = (
    kNone, kNull, kFalse, kTrue, kString,
    kNumber, // 不确认是 int 还是 float 类型
    kObject, kArray);

  TJsonVarPoint = record
    x: DWORD;
    y: DWORD;
  end;

  TJSONParser = record
    JSON: string;
    Index: integer;
    JSONLength: integer;
    TokenIdx: Integer;
    TokenLen : integer;
    function GetToken: string;
    procedure Init(const aJSON: string; aIndex, aLen: integer);
    function GetNextChar: char;               // inline;
    function GetNextNonWhiteChar: char;        //inline;
    function CheckNextNonWhiteChar(aChar: char): boolean; //inline;

    function GetNextString: boolean;
    function GetNextToken: string;
    function GetNextJSON: TJSONParserKind;
    function CheckNextIdent(const ExpectedIdent: string): Boolean;
    function GetNextAlphaPropName(out fieldName: string): boolean;
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

procedure TJSONParser.Init(const aJSON: string; aIndex, aLen: integer);
begin
  JSON := aJSON;
  if aLen > 0 then
    JSONLength := aLen + aIndex
  else
    JSONLength := length(JSON);
  Index := aIndex;
end;

function TJSONParser.GetNextChar: char;
begin
  if Index<=JSONLength then
  begin
    result := JSON[Index];
    inc(Index);
  end
  else
    result := #0;
end;

function TJSONParser.GetNextNonWhiteChar: char;
begin
  if Index<=JSONLength then
    repeat
      if JSON[Index]>' ' then
      begin
        result := JSON[Index];
        inc(Index);
        exit;
      end;
      inc(Index);
    until Index>JSONLength;
  result := #0;
end;

function TJSONParser.CheckNextNonWhiteChar(aChar: char): boolean;
begin
  if Index<=JSONLength then
    repeat
      if JSON[Index]>' ' then
      begin
        result := JSON[Index] = aChar;
        if result then
          inc(Index);
        exit;
      end;
      inc(Index);
    until Index>JSONLength;
  result := false;
end;

procedure TJSONParser.AppendNextStringUnEscape(var str: string);
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

function TJSONParser.GetNextString: boolean;
var i: integer;
begin
  result := false;
  for i := Index to JSONLength do
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

function TJSONParser.GetNextToken: string;
begin
  if GetNextString then
    Result := GetToken
  else result := '';
end;

function TJSONParser.GetNextAlphaPropName(out fieldName: string): boolean;
var i: integer;
begin
  result := False;
  if (Index>=JSONLength) or
     not (Ord(JSON[Index]) in [Ord('A')..Ord('Z'),Ord('a')..Ord('z'),Ord('_'),Ord('$')]) then
    exit; // first char must be alphabetical
  for i := Index+1 to JSONLength do
    case Ord(JSON[i]) of
    Ord('0')..Ord('9'),Ord('A')..Ord('Z'),Ord('a')..Ord('z'),Ord('_'):
      ; // allow MongoDB extended syntax, e.g. {age:{$gt:18}}
    Ord(':'),Ord('='): begin // allow both age:18 and age=18 pairs
      fieldName := Copy(JSON,Index,i-Index);
      Index := i+1;
      result := true;
      exit;
    end;
    else exit;
    end;
end;

function TJSONParser.GetNextJSON: TJSONParserKind;
var str: string;
    i64: Int64;
    d: double;
    start,err: integer;
begin
  result := kNone;
  case GetNextNonWhiteChar of
  'n': begin //if copy(JSON,Index,3)='ull' then begin
         inc(Index,3);
         result := kNull;
       end;
  'f': begin //if copy(JSON,Index,4)='alse' then begin
         inc(Index,4);
         result := kFalse;
       end;
  't': begin //if copy(JSON,Index,3)='rue' then begin
         inc(Index,3);
         result := kTrue;
       end;
  '"': if GetNextString then begin
         result := kString;
       end;
  '{': if ReadJSONObject then
         result := kObject;
  '[': if ReadJSONArray then
         result := kArray;
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

function TJSONParser.CheckNextIdent(const ExpectedIdent: string): Boolean;
begin
  result := (GetNextNonWhiteChar='"') and
            (CompareText(GetNextToken,ExpectedIdent)=0) and
            (GetNextNonWhiteChar=':');
end;

function TJSONParser.GetToken: string;
begin
  Result := copy(JSON,TokenIdx,tokenLen);
end;

function TJSONParser.ReadJSONArray: boolean;
var
  level: Integer;
begin
  TokenIdx := Index - 1;
  level := 0;
  result := false;
  if Index <= JSONLength then
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
    until Index>JSONLength;
end;

function TJSONParser.ReadJSONObject: boolean;
var
  level: Integer;
begin
  TokenIdx := Index - 1;
  level := 0;
  result := false;
  if Index <= JSONLength then
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
    until Index>JSONLength;
end;

end.
