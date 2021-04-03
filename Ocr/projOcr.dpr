program projOcr;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'uMain.pas' {FrmMain},
  uSbCloudVision in '..\Lib\uSbCloudVision.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
