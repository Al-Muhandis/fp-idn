program testgui;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, test_idn_n_punycode
  ;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

