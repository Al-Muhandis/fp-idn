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

  IDNToUnicode / TryIDNToUnicode decode every xn-- label back to UTF-8
  (Stage 4). The prefix is recognized case-insensitively (DNS is
  case-insensitive) and the label is lowercased before decoding, so
  mixed-case A-labels such as 'Xn--Mnchen-3ya' decode to lowercase Unicode
  ('münchen'). An xn-- label that fails punycode decoding is kept verbatim
  (in its original case) instead of failing the whole domain or being
  silently dropped, so the result never loses a label. As a consequence
  the decode direction currently always succeeds: the Try* signature is
  kept for contract symmetry with TryUnicodeToIDN. }

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

// Lowercase ASCII letters only. Punycode digits are case-insensitive and
// the basic part of a label must be ASCII, so this locale-independent
// lowering is exactly what the IDN decode needs (IDNA nameprep lowercases
// the label before ToUnicode as well). Non-ASCII bytes are left untouched:
// they make an xn-- label undecodable anyway, and the original label is
// kept on failure.
function LowercaseASCII(const S: string): string;
var
  i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if Result[i] in ['A'..'Z'] then
      Result[i] := Chr(Ord(Result[i]) + 32);
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

// Core IDN decoder with the Try* error contract (Stage 4): the xn-- prefix
// is recognized in any case, the label is lowercased before decoding, and
// a label that cannot be decoded is kept verbatim (original case) instead
// of failing the whole domain or being silently dropped — the result never
// loses a label, so a decode round-trip cannot collapse the domain. The
// decode direction therefore currently always succeeds; the Boolean
// contract is kept for symmetry with TryUnicodeToIDN.
function TryIDNToUnicode(const aDomain: string; out Unicode: string): Boolean;
var
  aParts: TStringArray;
  aDecodedParts: TStringArray = ();
  i: Integer;
  aPuny: string;
begin
  Unicode := EmptyStr;
  aParts := aDomain.Split(['.']);
  SetLength(aDecodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    // DNS is case-insensitive, so the prefix must match in any case
    if aParts[i].StartsWith('xn--', True) then
    begin
      // Decode the lowercased copy: mixed-case A-labels ('Xn--Mnchen-3ya')
      // produce lowercase Unicode ('münchen'), as IDNA ToUnicode does
      if TryPunycodeToUTF8(LowercaseASCII(aParts[i]).Remove(0, 4), aPuny) then
        aDecodedParts[i] := aPuny
      else
        // Undecodable label: keep the original verbatim instead of
        // dropping it (Stage 3 failure of the whole domain was replaced
        // by label preservation in Stage 4)
        aDecodedParts[i] := aParts[i];
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
