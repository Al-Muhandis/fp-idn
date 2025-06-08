program benchconsole;

{$mode objfpc}{$H+}

uses
  SysUtils, fppunycode, fpidn
  ;

type
  TBenchmark = record
    Name: string;
    Iterations: Integer;
    DurationMs: QWord;
    OpsPerSec: Double;
  end;

  TConvFunc = function(const S: string): string;

procedure RunBench(const Name, Input: string; Func: TConvFunc; Iterations: Integer; out Res: TBenchmark);
var
  i: Integer;
  StartT, EndT: QWord;
  Last, Expected: string;
begin
  Last:=EmptyStr;
  Expected := Func(Input);
  StartT := GetTickCount64;
  for i := 1 to Iterations do
    Last := Func(Input);
  EndT := GetTickCount64;
  if Last <> Expected then
    raise Exception.CreateFmt('%s failed: expected %s got %s', [Name, Expected, Last]);
  Res.Name := Name;
  Res.Iterations := Iterations;
  Res.DurationMs := EndT - StartT;
  if Res.DurationMs > 0 then
    Res.OpsPerSec := (Iterations * 1000.0) / Res.DurationMs
  else
    Res.OpsPerSec := Iterations;
end;

procedure SaveCSV(const FileName: string; const Results: array of TBenchmark);
var
  F: TextFile;
  i: Integer;
begin
  AssignFile(F, FileName);
  Rewrite(F);
  WriteLn(F, 'Name,Iterations,DurationMs,OpsPerSec');
  for i := 0 to High(Results) do
    WriteLn(F, Format('"%s";%d;%d;%.2f',
      [Results[i].Name, Results[i].Iterations, Results[i].DurationMs, Results[i].OpsPerSec]));
  CloseFile(F);
end;

procedure PrintResults(const Results: array of TBenchmark);
var
  i: Integer;
begin
  Writeln('Benchmark results:');
  Writeln(Format('%-30s %10s %12s %12s', ['Name','Iterations','Duration','Ops/s']));
  for i := 0 to High(Results) do
    Writeln(Format('%-30s %10d %12d %12.2f',
      [Results[i].Name, Results[i].Iterations, Results[i].DurationMs, Results[i].OpsPerSec]));
end;

const
  ITERATIONS = 100000;

var
  Results: array of TBenchmark;
  LongStr, LongPuny: string;
  i: Integer;
begin
  LongStr:=EmptyStr;
  for i := 1 to 1000 do
    LongStr+='т';
  LongPuny := UTF8ToPunycode(LongStr);

  Initialize(Results);
  SetLength(Results, 8);

  RunBench('UTF8ToPunycode short', 'тест', @UTF8ToPunycode, ITERATIONS, Results[0]);
  RunBench('PunycodeToUTF8 short', 'e1aybc', @PunycodeToUTF8, ITERATIONS, Results[1]);
  RunBench('UTF8ToPunycode long', LongStr, @UTF8ToPunycode, ITERATIONS, Results[2]);
  RunBench('PunycodeToUTF8 long', LongPuny, @PunycodeToUTF8, ITERATIONS, Results[3]);
  RunBench('UnicodeToIDN', 'пример.рф', @UnicodeToIDN, ITERATIONS, Results[4]);
  RunBench('IDNToUnicode', 'xn--e1afmkfd.xn--p1ai', @IDNToUnicode, ITERATIONS, Results[5]);
  RunBench('UnicodeToIDN', 'example.com', @UnicodeToIDN, ITERATIONS, Results[6]);
  RunBench('IDNToUnicode', 'example.com', @IDNToUnicode, ITERATIONS, Results[7]);

  PrintResults(Results);
  SaveCSV('results.csv', Results);
end.
