unit fpidn;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fppunycode;

{ Domain-level IDN wrapper over the punycode converter.

  Error contract (Stage 3): the Try* functions are the primary API. They
  return True on success with the output parameter filled, and False on
  invalid input with the output parameter guaranteed to be EmptyStr. An
  empty domain is a success with an empty result, not an error.

  The plain functions (UnicodeToIDN, IDNToUnicode) are compatibility
  wrappers around the Try* pair: on any failure they return EmptyStr.

  UnicodeToIDN / TryUnicodeToIDN take a UTF-8 domain and encode every
  non-ASCII label as an xn-- label; empty labels pass through unchanged.
  Failure reasons: a non-ASCII label that fails punycode encoding (that
  is, malformed UTF-8 or RFC 3492 section 6.4 arithmetic overflow) fails
  the whole domain instead of emitting a broken 'xn--' label.

  IDNToUnicode / TryIDNToUnicode decode every xn-- label back to UTF-8.
  Failure reasons: an xn-- label that fails punycode decoding fails the
  whole domain instead of silently dropping the label. }

function TryUnicodeToIDN(const aDomain: string; out IDN: string): Boolean;
function TryIDNToUnicode(const aDomain: string; out Unicode: string): Boolean;
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

// Core IDN encoder with the Try* error contract (Stage 3): internal checks
// report success/failure via Boolean instead of relying on the "empty
// string = error" convention of the punycode layer. IDN is guaranteed to
// be EmptyStr when False is returned; the plain UnicodeToIDN below is a
// thin wrapper projecting False to EmptyStr.
function TryUnicodeToIDN(const aDomain: string; out IDN: string): Boolean;
var
  aParts: TStringArray;
  aEncodedParts: TStringArray = ();
  i: Integer;
  aPuny: string;
begin
  IDN := EmptyStr;
  aParts := aDomain.Split(['.']);
  SetLength(aEncodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    if aParts[i] = EmptyStr then
      aEncodedParts[i] := EmptyStr
    else if IsASCII(aParts[i]) then
      aEncodedParts[i] := aParts[i]
    else
    begin
      // A non-ASCII label that cannot be encoded (malformed UTF-8 or
      // overflow) fails the whole domain instead of producing a broken
      // 'xn--' label
      if not TryUTF8ToPunycode(aParts[i], aPuny) then
        Exit(False);
      aEncodedParts[i] := 'xn--' + aPuny;
    end;
  end;

  IDN := IDN.Join('.', aEncodedParts);
  Result := True;
end;

// Core IDN decoder with the Try* error contract (Stage 3): an xn-- label
// that cannot be decoded fails the whole domain instead of being silently
// dropped. Unicode is guaranteed to be EmptyStr when False is returned;
// the plain IDNToUnicode below is a thin wrapper projecting False to
// EmptyStr.
function TryIDNToUnicode(const aDomain: string; out Unicode: string): Boolean;
var
  aParts: TStringArray;
  aDecodedParts: TStringArray = ();
  i: Integer;
begin
  Unicode := EmptyStr;
  aParts := aDomain.Split(['.']);
  SetLength(aDecodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    if aParts[i].StartsWith('xn--') then
    begin
      if not TryPunycodeToUTF8(aParts[i].Remove(0, 4), aDecodedParts[i]) then
        Exit(False);
    end
    else
      aDecodedParts[i] := aParts[i];
  end;

  Unicode := Unicode.Join('.', aDecodedParts);
  Result := True;
end;

function UnicodeToIDN(const aDomain: string): string;
begin
  if not TryUnicodeToIDN(aDomain, Result) then
    Result := EmptyStr;
end;

function IDNToUnicode(const aDomain: string): string;
begin
  if not TryIDNToUnicode(aDomain, Result) then
    Result := EmptyStr;
end;

end.
