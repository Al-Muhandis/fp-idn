unit fpidn;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fppunycode;

function UnicodeToIDN(const aDomain: string): string;
function IDNToUnicode(const aDomain: string): string;

implementation

function IsASCII(const S: string): Boolean;
var
  ch: Char;
begin
  for ch in S do
    if Ord(ch) >= 128 then
      Exit(False);
  Result := True;
end;

function UnicodeToIDN(const aDomain: string): string;
var
  aParts: TStringArray;
  aEncodedParts: TStringArray = ();
  i: Integer;
begin
  Result := EmptyStr;
  aParts := aDomain.Split(['.']);
  SetLength(aEncodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    if aParts[i] = EmptyStr then
      aEncodedParts[i] := EmptyStr
    else if IsASCII(aParts[i]) then
      aEncodedParts[i] := aParts[i]
    else
      aEncodedParts[i] := 'xn--' + UTF8ToPunycode(aParts[i]);
  end;

  Result := Result.Join('.', aEncodedParts);
end;

function IDNToUnicode(const aDomain: string): string;
var
  aParts: TStringArray;
  aDecodedParts: TStringArray = ();
  i: Integer;
begin
  aParts := aDomain.Split(['.']);
  SetLength(aDecodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    if aParts[i].StartsWith('xn--') then
      aDecodedParts[i] := PunycodeToUTF8(aParts[i].Remove(0, 4))
    else
      aDecodedParts[i] := aParts[i];
  end;

  Result := aDomain.Join('.', aDecodedParts);
end;

end.

