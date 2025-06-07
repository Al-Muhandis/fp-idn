unit test_idn_n_punycode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  { TTestPunycode }
  TTestPunycode = class(TTestCase)
  private
    procedure AssertEncodeDecode(const aTestName, aInput, ExpectedPunycode: string);
    procedure AssertRoundTrip(const aTestName, aInput: string);
  published
    // Basic encoding/decoding tests
    procedure TestRussianDomain;
    procedure TestChineseCharacters;
    procedure TestArabicText;
    procedure TestGermanUmlaut;
    procedure TestJapaneseText;
    procedure TestMixedContent;
    // Edge cases
    procedure TestEmptyString;
    procedure TestSingleCharacter;
    procedure TestLongString;
    procedure TestOnlyNonASCII;
    // Special cases
    procedure TestSpecialCharacters;
    procedure TestNumbersAndSymbols;
    procedure TestCaseInsensitive;
    // Error handling tests
    procedure TestInvalidPunycode;
    procedure TestCorruptedData;
    // Performance tests
    procedure TestLargeData;
    // Real-world domain examples
    procedure TestRealWorldDomains;
    procedure TestDisallowedCharacters;
    procedure TestMalformedStructure;
    procedure TestDeterministicEncoding;

  end;

  { TTestIDN }

  TTestIDN = class(TTestCase)
  published
    procedure TestPureASCII;
    procedure TestRussianIDN;
    procedure TestMixedDomain;
    procedure TestSubdomains;
    procedure TestRealDomain;
    procedure TestEmptyInput;
  end;

implementation

uses
  fppunycode, fpidn
  ;

procedure TTestPunycode.AssertEncodeDecode(const aTestName, aInput, ExpectedPunycode: string);
var
  aEncoded, aDecoded: string;
begin
  aEncoded := UTF8ToPunycode(aInput);
  AssertEquals(aTestName + ': encoding mismatch', ExpectedPunycode, aEncoded);
  aDecoded := PunycodeToUTF8(aEncoded);
  AssertEquals(aTestName, aInput, aDecoded);
end;

procedure TTestPunycode.AssertRoundTrip(const aTestName, aInput: string);
var
  aEncoded, aDecoded: string;
begin
  aEncoded := UTF8ToPunycode(aInput);
  aDecoded := PunycodeToUTF8(aEncoded);
  AssertEquals(Format('%s: data changed after round-trip', [aTestName]), aInput, aDecoded);
end;

procedure TTestPunycode.TestRussianDomain;
begin
  // Test Cyrillic characters
  AssertRoundTrip('Cyrillic word', 'пример');
  AssertRoundTrip('Test', 'испытание');

  // Known results
  AssertEncodeDecode('Test', 'тест', 'e1aybc');
end;

procedure TTestPunycode.TestChineseCharacters;
begin
  // Chinese characters
  AssertRoundTrip('China', '中国');
  AssertRoundTrip('Chinese text', '中文域名');
end;

procedure TTestPunycode.TestArabicText;
begin
  // Arabic text
  AssertRoundTrip('Arabic', 'العربية');
  AssertRoundTrip('Arabic domain', 'مثال');
end;

procedure TTestPunycode.TestGermanUmlaut;
begin
  // German characters with umlauts
  AssertRoundTrip('München', 'München');
  AssertRoundTrip('Bücher', 'Bücher');
end;

procedure TTestPunycode.TestJapaneseText;
begin
  // Japanese Character
  AssertRoundTrip('Japan', '日本');
  AssertRoundTrip('Japanese text', 'ドメイン名例');
end;

procedure TTestPunycode.TestMixedContent;
begin
  // Mixed content: ASCII + Unicode
  AssertRoundTrip('Mixed 1', 'hello世界');
  AssertRoundTrip('Mixed 2', 'тест-123');
  AssertRoundTrip('Mixed 3', 'example中文');
end;

procedure TTestPunycode.TestEmptyString;
begin
  // Empty string
  AssertEncodeDecode('Empty string', '', '');
end;

procedure TTestPunycode.TestSingleCharacter;
begin
  // Single character cases
  AssertRoundTrip('One cyrillic character', 'а');
  AssertRoundTrip('One chinese character', '中');
end;

procedure TTestPunycode.TestLongString;
var
  aLongRussian: String;
  i: Integer;
begin
  // Long string
  aLongRussian := EmptyStr;
  for i := 1 to 100 do
    aLongRussian+='тест';

  AssertRoundTrip('Long string', aLongRussian);
end;

procedure TTestPunycode.TestOnlyNonASCII;
begin
  // Only non-ASCII characters
  AssertRoundTrip('Only cyrillic', 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя');
  AssertRoundTrip('Only chinese', '一二三四五六七八九十');
end;

procedure TTestPunycode.TestSpecialCharacters;
begin
  // Special Unicode characters
  AssertRoundTrip('Currency symbols', '€£¥₽');
  AssertRoundTrip('Mathematical symbols', '∑∏∫∆');
  AssertRoundTrip('Emoji', '😀😃😄😁');
end;

procedure TTestPunycode.TestNumbersAndSymbols;
begin
  // Numbers and symbols mixed
  AssertRoundTrip('Digits with Cyrillic', 'тест123');
  AssertRoundTrip('Symbols with Chinese', '中国-test');
end;

procedure TTestPunycode.TestCaseInsensitive;
var
  aLower, aUpper, aCombined: string;
begin
  // Test case insensitivity of Punycode
  aLower := UTF8ToPunycode('тест');
  aUpper := UTF8ToPunycode('ТЕСТ');  
  aCombined := UTF8ToPunycode('Тест');

  // All must be converted correctly
  AssertEquals('Lowercase', 'тест', PunycodeToUTF8(aLower));
  AssertEquals('Uppercase', 'ТЕСТ', PunycodeToUTF8(aUpper));
  AssertEquals('Capitalized', 'Тест', PunycodeToUTF8(aCombined));
end;

procedure TTestPunycode.TestInvalidPunycode;
var
  aInvalidResult: string;
begin
  // Invalid punycode string test
  aInvalidResult := PunycodeToUTF8('invalid-punycode-string');
  // The main point is the function should not raise exceptions
  AssertTrue('The function must execute without errors', aInvalidResult <> EmptyStr);
end;

procedure TTestPunycode.TestCorruptedData;
var
  {%H-}Result1, {%H-}Result2: string;
begin
  // Corrupted data test
  Result1 := PunycodeToUTF8('xn--');
  Result2 := PunycodeToUTF8('xn--invalid');

  // should not raise exceptions
  AssertTrue('Correpted data processed', True);
end;

procedure TTestPunycode.TestLargeData;
var
  aLargeString: string;
  i: Integer;
begin
  // Big data test
  aLargeString := '';
  for i := 1 to 1000 do
    aLargeString := aLargeString + 'тест' + IntToStr(i) + 'test';

  AssertRoundTrip('Big data', aLargeString);
end;

procedure TTestPunycode.TestRealWorldDomains;
begin
  // Real-world examples of internationalized domain names
  AssertRoundTrip('Wikipedia', 'википедия'); // википедия.org
  AssertRoundTrip('Mail', 'почта'); // почта.рф
end;

procedure TTestPunycode.TestDisallowedCharacters;
begin
  AssertEquals('Corrupted character (cyrillic)', EmptyStr, PunycodeToUTF8('пример'));
  AssertEquals('Corrupted character (%)', EmptyStr, PunycodeToUTF8('ab%cd'));
end;

procedure TTestPunycode.TestMalformedStructure;
begin
  AssertEquals('Only delimiter', EmptyStr, PunycodeToUTF8('-'));
end;

procedure TTestPunycode.TestDeterministicEncoding;
begin
  AssertEquals('Deterministic encoding', UTF8ToPunycode('пример'), UTF8ToPunycode('пример'));
end;

{ TTestIDN }

procedure TTestIDN.TestPureASCII;
begin
  AssertEquals('Pure ASCII domain remains unchanged',
               'example.com', UnicodeToIDN('example.com'));
  AssertEquals('Pure ASCII domain round-trip',
               'example.com', IDNToUnicode('example.com'));
end;

procedure TTestIDN.TestRussianIDN;
begin
  AssertEquals('Russian domain to IDN',
               'xn--e1afmkfd.xn--p1ai', UnicodeToIDN('пример.рф'));
  AssertEquals('Russian domain to Unicode',
               'пример.рф', IDNToUnicode('xn--e1afmkfd.xn--p1ai'));
end;

procedure TTestIDN.TestMixedDomain;
begin
  AssertEquals('Mixed domain to IDN',
               'xn--mnchen-3ya.com', UnicodeToIDN('münchen.com'));
  AssertEquals('Mixed domain to Unicode',
               'münchen.com', IDNToUnicode('xn--mnchen-3ya.com'));
end;

procedure TTestIDN.TestSubdomains;
begin
  AssertEquals('Subdomain with IDN', 'mail.xn--80a1acny', UnicodeToIDN('mail.почта'));
  AssertEquals('Subdomain Unicode', 'mail.онлайн', IDNToUnicode('mail.xn--80asehdb'));
end;

procedure TTestIDN.TestRealDomain;
begin
  AssertEquals('Real .org domain', 'xn--d1acufc.xn--p1ai', UnicodeToIDN('домен.рф'));
  AssertEquals('Real .org domain decoded',
               'домен.рф', IDNToUnicode('xn--d1acufc.xn--p1ai'));
end;

procedure TTestIDN.TestEmptyInput;
begin
  AssertEquals('Empty input to IDN', '', UnicodeToIDN(''));
  AssertEquals('Empty input from IDN', '', IDNToUnicode(''));
end;

initialization

  RegisterTest(TTestPunycode);  
  RegisterTest(TTestIDN);
end.

