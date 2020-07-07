unit uJsonReaders;

///
///  json 顺序解析读取
///

interface

//{$define HASINLINE}




uses
  Classes, Windows, SysUtils;

type
  TJSONReaderKind = (
    jrkNone, jrkNull, jrkFalse, jrkTrue, jrkString,
    jrkNumber, // 不确定 int 还是 float 类型
    jrkObject, jrkArray);

  TJSONReader = record
    JSON: PChar;
    Curr: PChar;
    Last: PChar;
    Token: PChar;
    TokenLen : integer;
    ExistsEscapeChar: Boolean;
    procedure Init(const AJSON: PChar; ALen: Integer);
    function GetNextChar: char;                           {$ifdef HASINLINE} inline; {$endif}
    function GetNextNonWhiteChar: char;                   {$ifdef HASINLINE} inline; {$endif}
    function JSONStrToStr: string;
    function GetToken: string;                            {$ifdef HASINLINE} inline; {$endif}
    function GetToStrToken: string;                       {$ifdef HASINLINE} inline; {$endif}

    function GetNextString: boolean;
    function GetNextToken: string;
    function ReadJSONObject: boolean;
    function ReadJSONArray: boolean;
    procedure AppendNextStringUnEscape; //(var str: string);

    function GetDataType: TJSONReaderKind;
    function GetNext: TJSONReaderKind;
    function GetNextOf(const id: string): TJSONReaderKind;

    function AsStr: string;     {$ifdef HASINLINE} inline; {$endif}
    function AsInt: Integer;    {$ifdef HASINLINE} inline; {$endif}
    function AsInt64: Int64;    {$ifdef HASINLINE} inline; {$endif}
    function AsUInt64: UInt64;  {$ifdef HASINLINE} inline; {$endif}
    function AsFloat: Extended; {$ifdef HASINLINE} inline; {$endif}
  end;

implementation

uses
  Math;

//procedure AppendChar(var str: string; chr: Char);
//var len: Integer;
//begin
//  len := length(str);
//  SetLength(str,len+1);
//  PChar(pointer(str))[len] := chr;
//end;

procedure HexTo(c: Char; var d: LongWord); {$ifdef HASINLINE} inline; {$endif}
begin
  case c of
    '0'..'9': d := (d shl 4) or LongWord(Ord(c) - Ord('0'));
    'A'..'F': d := (d shl 4) or LongWord(Ord(c) - (Ord('A') - 10));
    'a'..'f': d := (d shl 4) or LongWord(Ord(c) - (Ord('a') - 10));
    else raise Exception.Create('Error Message');
  end;
end;




//procedure AppendChar(var str: string; chr: Char);
//var len: Integer;
//begin
//  len := length(str);
//  SetLength(str,len+1);
//  PChar(pointer(str))[len] := chr;
//end;

procedure TJSONReader.Init(const AJSON: PChar; ALen: Integer);
begin
  JSON := AJSON;
  Curr := JSON;
  if ALen <= 0 then
    ALen := StrLen(JSON);
  Last := (Curr + ALen);
end;

function TJSONReader.GetNextChar: char;
begin
  if Curr < Last then
  begin
    Result := Curr^;
    inc(Curr);
  end
  else
    result := #0;
end;

function TJSONReader.GetNextNonWhiteChar: char;
begin
  if Curr < Last then
    repeat
      if Curr^ > ' ' then
      begin
        result := Curr^;
        inc(Curr);
        exit;
      end;
      inc(Curr);
    until Curr > Last;
  result := #0;
end;

procedure TJSONReader.AppendNextStringUnEscape; //(var str: string);
var
  c: char;
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
            'u': inc(Curr, 4);
          end;
        end;
    end;
    TokenLen := (Curr - Token);
  until false;
end;

function TJSONReader.GetToken: string;
begin
  SetString(Result, Token, TokenLen);
end;

function TJSONReader.GetToStrToken: string;
begin
  if not ExistsEscapeChar then
    Result := GetToken
  else
    Result := JSONStrToStr;
end;

function TJSONReader.GetNextString: boolean;
begin
  Token := Curr;
  TokenLen := 0;
  result := false;
  while Curr < Last do
  begin
    case Curr^ of
    '"': begin
          TokenLen := Curr - Token;
          inc(Curr);
          result := true;
          break;
        end;
    '\': begin // need unescaping
          ExistsEscapeChar := True;
          case GetNextChar of
            #0: Exit;
            'u': begin
                  inc(Curr, 4);
                  if Curr >= Last then
                    Exit;
                end;
          end;
        end;
    end;
    inc(Curr);
  end;
end;

function TJSONReader.GetNextToken: string;
begin
  if GetNextString then
    Result := GetToken
  else result := '';
end;

function TJSONReader.GetDataType: TJSONReaderKind;
begin
  // 第一次读取
  //   确定数据类型： 1、对象类型
  //                  2、数组类型
  //
  case GetNextNonWhiteChar of
    '{': Result := jrkObject;
    '[': Result := jrkArray;
    else Result := jrkNone;
  end;
end;

function TJSONReader.GetNext: TJSONReaderKind;
begin
  ExistsEscapeChar := False;
  result := jrkNone;
  case GetNextNonWhiteChar of
    'n': begin //if copy(JSON,CurIdx,3)='ull' then begin
           inc(Curr,3);
           result := jrkNull;
         end;
    'f': begin //if copy(JSON,CurIdx,4)='alse' then begin
           inc(Curr,4);
           result := jrkFalse;
         end;
    't': begin //if copy(JSON,CurIdx,3)='rue' then begin
           inc(Curr,3);
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
        Token := Curr - 1;
        while true do
          case Curr^ of
            '-','+','0'..'9','.','E','e': inc(Curr);
          else break;
          end;
        TokenLen := Curr - Token;
        Result := jrkNumber;
      end;
  end;
end;

function TJSONReader.GetNextOf(const id: string): TJSONReaderKind;
var
  bSurr: Boolean;
  c: char;
  I: Integer;
  k: TJSONReaderKind;
begin
  Result := jrkNone;
  while True do
  begin
    if GetNext <> jrkString then
      Break;

    bSurr := SameText(id, AsStr);
    if not (GetNextNonWhiteChar = ':') then
      Exit;

    k := GetNext;
    if bSurr then
    begin
      Result := k;
      Break;
    end;

    c := GetNextNonWhiteChar;
    if (c = '}') or (c = #0) then
      Break;
  end;
end;

function TJSONReader.JSONStrToStr: string;

const
  MaxBufPos = 127;
var
  Buf: array[0..MaxBufPos] of Char;
  BufPos, Len: Integer;
  d: LongWord;
  s: string;
  pWordCurr, pWordLast: PChar;
begin
  if TokenLen <= 0 then
  begin
    Result := '';
    Exit;
  end;

  s := '';
  pWordCurr := Token;
  pWordLast := pWordCurr + TokenLen;

  BufPos := 0;
  while pWordCurr < pWordLast do
  begin
    if pWordCurr^ <> '\' then
      Buf[BufPos] := pWordCurr^
    else //if JSON[idx] = '\' do
    begin
      inc(pWordCurr);
      if pWordCurr >= pWordLast then Break;
      case pWordCurr^ of
        '"': Buf[BufPos] := '"';
        '\': Buf[BufPos] := '\';
        '/': Buf[BufPos] := '/';
        'b': Buf[BufPos] := #8;
        'f': Buf[BufPos] := #12;
        'n': Buf[BufPos] := #10;
        'r': Buf[BufPos] := #13;
        't': Buf[BufPos] := #9;
        'u': begin
            if pWordCurr + 4 >= pWordLast then Break;
            d := 0;
            HexTo((pWordCurr+1)^, d);
            HexTo((pWordCurr+2)^, d);
            HexTo((pWordCurr+3)^, d);
            HexTo((pWordCurr+4)^, d);
            Buf[BufPos] := Char(d);
            inc(pWordCurr, 4);
          end;
      else  Break;
      end;
    end;
    Inc(pWordCurr);
    Inc(BufPos);

    if BufPos > MaxBufPos then
    begin
      Len := Length(s);
      SetLength(S, Len + BufPos);
      Move(Buf[0], PChar(Pointer(S))[Len], BufPos * SizeOf(Char));
      BufPos := 0;
    end;
  end;

  if BufPos > 0 then
  begin
    Len := Length(S);
    SetLength(S, Len + BufPos);
    Move(Buf[0], PChar(Pointer(S))[Len], BufPos * SizeOf(Char));
  end;

  Result := s;
end;

function TJSONReader.ReadJSONArray: boolean;
var
  level: Integer;
begin
  Token := Curr - 1; // 包括括号
  level := 0;
  result := false;
  if Curr < Last then
    repeat
      case Curr^ of
        '[': inc(level);
        ']': begin
          if level = 0 then
          begin
            inc(Curr);
            TokenLen := Curr - Token;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(Curr);
    until Curr > Last;
end;

function TJSONReader.ReadJSONObject: boolean;
var
  level: Integer;
begin
  Token := Curr - 1; // 包括括号
  level := 0;
  result := false;
  if Curr <= Last then
    repeat
      case Curr^ of
        '{': inc(level);
        '}': begin
          if level = 0 then
          begin
            inc(Curr);
            TokenLen := Curr - Token;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(Curr);
    until Curr > Last;
end;

function TJSONReader.AsStr: string;
begin
  Result := GetToStrToken;
end;

function TJSONReader.AsInt: Integer;
begin
  Result := integer(AsInt64);
end;

function TJSONReader.AsInt64: Int64;
var
  err: Integer;
  i64: Int64;
  d: Extended;
  str: string;
begin
  Result := 0;
  str := GetToken;
  val(str,i64,err);
  if err=0 then
    Result := i64
  else
  begin
    val(str,d,err);
    if err = 0 then
      Result := Round(d);
  end;
end;

function TJSONReader.AsUInt64: UInt64;
begin
  Result := UInt64(AsInt64);
end;

function TJSONReader.AsFloat: Extended;
var
  err: Integer;
  i64: UInt64;
  d: Extended;
  str: string;
begin
  Result := 0;
  str := GetToken;
  val(str, d, err);
  if err = 0 then
    Result := d
  else begin
    val(str, i64, err);
    if err = 0 then
      Result := i64;
  end;
end;


end.
