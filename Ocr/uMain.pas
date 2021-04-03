unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects, FMX.Layouts, System.Actions, FMX.ActnList,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.StdActns, FMX.MediaLibrary.Actions, System.Permissions, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

type
  TFrmMain = class(TForm)
    LytBottom: TLayout;
    LytTop: TLayout;
    Rectangle1: TRectangle;
    Text1: TText;
    BtnCamera: TSpeedButton;
    ActionList1: TActionList;
    TakePhotoFromCameraAction1: TTakePhotoFromCameraAction;
    LytImg: TLayout;
    ImgPhoto: TImage;
    BtnOk: TSpeedButton;
    LytMemo: TLayout;
    MemResponse: TMemo;
    procedure TakePhotoFromCameraAction1DidFinishTaking(Image: TBitmap);
    procedure FormCreate(Sender: TObject);
    procedure BtnCameraClick(Sender: TObject);
    procedure BtnOkClick(Sender: TObject);
  private
    FPermissionCamera,
    FPermissionReadExternalStorage,
    FPermissionWriteExternalStorage: string;
    procedure DisplayRationale(Sender: TObject; const APermissions: TArray<string>; const APostRationaleProc: TProc);
    procedure TakePicturePermissionRequestResult(Sender: TObject; const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>);
    function ImgToBase64: String;
  public
    { Public declarations }
  end;

var
  FrmMain: TFrmMain;

implementation
  uses Androidapi.Helpers, Androidapi.JNI.JavaTypes, Androidapi.JNI.Os, FMX.DialogService, uSbCloudVision, Soap.EncdDecd;
{$R *.fmx}

procedure TFrmMain.BtnCameraClick(Sender: TObject);
begin
  PermissionsService.RequestPermissions([FPermissionCamera, FPermissionReadExternalStorage, FPermissionWriteExternalStorage], TakePicturePermissionRequestResult, DisplayRationale);
end;

function TFrmMain.ImgToBase64:String;
var
  Input: TBytesStream;
  Output: TStringStream;
begin
  Input := TBytesStream.Create;
  try
    ImgPhoto.Bitmap.SaveToStream(Input);
    Input.Position := 0;
    Output := TStringStream.Create('', TEncoding.ASCII);
    try
      Soap.EncdDecd.EncodeStream(Input, Output);
      Result := Output.DataString;
    finally
      Output.Free;
    end;
  finally
    Input.Free;
  end;
end;

procedure TFrmMain.BtnOkClick(Sender: TObject);
var
  SbCloudVision : TSbCloudVision;
  xParam : TOcrParam;
begin
  SbCloudVision := TSbCloudVision.Create(nil);
  try
    SbCloudVision.ApiKey := '';
    xParam.ImgSource := ImgToBase64;
    MemResponse.Text := SbCloudVision.GetImageToOcrText(xParam).TextStr;
  finally
    FreeAndNil(SbCloudVision)
  end;
end;

procedure TFrmMain.DisplayRationale(Sender: TObject; const APermissions: TArray<string>; const APostRationaleProc: TProc);
var
  I: Integer;
  RationaleMsg: string;
begin
  for I := 0 to High(APermissions) do
  begin
    if APermissions[I] = FPermissionCamera then
      RationaleMsg := RationaleMsg + 'The app needs to access the camera to take a photo' + SLineBreak + SLineBreak
    else if APermissions[I] = FPermissionReadExternalStorage then
      RationaleMsg := RationaleMsg + 'The app needs to read a photo file from your device';
  end;

  TDialogService.ShowMessage(RationaleMsg,
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end);
end;
procedure TFrmMain.FormCreate(Sender: TObject);
begin
  FPermissionCamera := JStringToString(TJManifest_permission.JavaClass.CAMERA);
  FPermissionReadExternalStorage := JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE);
  FPermissionWriteExternalStorage := JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);
end;

procedure TFrmMain.TakePhotoFromCameraAction1DidFinishTaking(Image: TBitmap);
begin
  ImgPhoto.Bitmap.Assign(Image);
  BtnOk.Visible := True;
end;

procedure TFrmMain.TakePicturePermissionRequestResult(Sender: TObject; const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>);
begin
  if (Length(AGrantResults) = 3) and (AGrantResults[0] = TPermissionStatus.Granted) and (AGrantResults[1] = TPermissionStatus.Granted) and (AGrantResults[2] = TPermissionStatus.Granted) then
    TakePhotoFromCameraAction1.Execute
  else
    TDialogService.ShowMessage('Cannot take a photo because the required permissions are not all granted');
end;

end.
