unit test_idn_n_punycode_property;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fppunycode, fpidn;

type
  { TTestPunycodeProperty }
  TTestPunycodeProperty = class(TTestCase)
  published
    procedure TestRandomRoundTrip;
    procedure TestRandomDomainsRoundTrip;
  end;

implementation

function RandomUnicodeString(ALength: Integer): string;
var
  i: Integer;
  c: Cardinal = 0;
begin
  Result := '';
  for i := 1 to ALength do
  begin
    // Generate random Unicode (Basic Latin, Cyrillic, CJK, Emoji)
    case Random(4) of
      0: c := Random(26) + Ord('a'); // ASCII lower
      1: c := $0400 + Random($4FF - $0400); // Cyrillic
      2: c := $4E00 + Random($9FFF - $4E00); // CJK
      3: c := $1F600 + Random($1F64F - $1F600); // Emoji
    end;
    if c <= $7F then
      Result += Chr(Byte(c))
    else if c <= $7FF then
      Result += Chr($C0 or (c shr 6)) + Chr($80 or (c and $3F))
    else if c <= $FFFF then
      Result += Chr($E0 or (c shr 12)) + Chr($80 or ((c shr 6) and $3F)) + Chr($80 or (c and $3F))
    else
      Result += Chr($F0 or (c shr 18)) + Chr($80 or ((c shr 12) and $3F)) + Chr($80 or ((c shr 6) and $3F)) + Chr($80 or (c and $3F));
  end;
end;

procedure TTestPunycodeProperty.TestRandomRoundTrip;
var
  i: Integer;
  s, puny, decoded: string;
begin
  // 100 random strings with different length
  for i := 1 to 100 do
  begin
    s := RandomUnicodeString(Random(30) + 1);
    puny := UTF8ToPunycode(s);
    decoded := PunycodeToUTF8(puny);
    AssertEquals('Property round-trip failed at iteration ' + IntToStr(i), s, decoded);
  end;
end;

procedure TTestPunycodeProperty.TestRandomDomainsRoundTrip;
var
  i, j, parts: Integer;
  domain, puny, decoded: string;
  part: string;
begin
  // 100 random domains with subdomains (ASCII и Unicode)
  for i := 1 to 100 do
  begin
    domain := EmptyStr;
    parts := 2 + Random(3); // from 2 to 4 subdomains
    for j := 1 to parts do
    begin
      if Random(2) = 0 then
        part := RandomUnicodeString(Random(8) + 1)
      else
        part := 'ascii' + IntToStr(Random(1000));
      if domain <> '' then
        domain += '.';
      domain += part;
    end;
    puny := UnicodeToIDN(domain);
    decoded := IDNToUnicode(puny);
    AssertEquals('IDN round-trip failed at iteration ' + IntToStr(i), domain, decoded);
  end;
end;

initialization
  RegisterTest(TTestPunycodeProperty);

end.
