{-----------------------------------------------------------------------------
 Unit Name: uSbCloudVision
 Author:    Salih BAÐCI
 Date:      03-Nis-2021
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit uSbCloudVision;

interface

  uses System.SysUtils, System.Classes, System.Generics.Collections, System.JSON, System.Types,
    System.Net.URLClient, System.Net.HttpClient, System.Net.HttpClientComponent;

  type TCloudVisionUrl=(UrlOcr);
  type TOcrFeatures=(FeaTextDetection,FeaDocumentTextDetection);
  type TOcrImgType=(ImgBase64,ImgUrl);

  type
  TOcrParam = record
    ImgType : TOcrImgType;
    Features : TOcrFeatures;
    ImgSource : String;
    Languages : TStringDynArray;
    class operator Initialize(out Dest:TOcrParam);
  end;

  type
  TOcrResult = record
    Error : Boolean;
    ErrorStr : String;
    TextStr : String;
    WordArr : TStringDynArray;
    class operator Initialize(out Dest:TOcrResult);
  end;

  type
  TSbCloudVision = class(TComponent)
  private
    FApiKey: String;
    function GetApiUrl(const AUrlType:TCloudVisionUrl):String;
    procedure NetCompSettingsSet(AReq:TNetHTTPRequest;ACli:TNetHTTPClient);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetImageToOcrText(const AOcrParam:TOcrParam):TOcrResult;
  published
    property ApiKey:String read FApiKey write FApiKey;
  end;

implementation

{ TSbCloudVision }

constructor TSbCloudVision.Create(AOwner: TComponent);
begin
  inherited;
  //
end;

destructor TSbCloudVision.Destroy;
begin
  //
  inherited;
end;

function TSbCloudVision.GetApiUrl(const AUrlType: TCloudVisionUrl): String;
begin
  case AUrlType of
    UrlOcr: Result := Format('https://vision.googleapis.com/v1/images:annotate?key=%s',[FApiKey]);
  end;
end;

function TSbCloudVision.GetImageToOcrText(const AOcrParam: TOcrParam): TOcrResult;
var
  Ind : Integer;
  xObjMain,xObjImage,xObjFeatures,xObjRequest,xObjImageSrc,xObjContext: TJSONObject;
  xArrRequest,xArrFeatures,xArrContext : TJSONArray;
  xObjGetMain,xObjFullTextAnnotation : TJSONObject;
  xArrResponses,xArrTextAnnotations : TJSONArray;
  xSendJsonStr : String;
  xGetJsonStr : String;
  xNetHttp : TNetHTTPRequest;
  xNetClient : TNetHTTPClient;
  xRepStringStream : TStringStream;
  xReqStringStream : TStringStream;
  xNetHeader : TNetHeaders;
  procedure SetErrorResult(const AErrorMessage:String);
  begin
    Result.Error := Trim(AErrorMessage) <> '';
    Result.ErrorStr := Trim(AErrorMessage);
    Result.TextStr := '';
  end;
begin
  {$REGION 'Json Create'}
    xObjMain := TJSONOBject.Create;
    try
      xArrRequest := TJSONArray.Create;
      xObjRequest := TJSONOBject.Create;
      xObjImage := TJSONOBject.Create;
      xArrFeatures := TJSONArray.Create;
      xObjFeatures := TJSONOBject.Create;

      case AOcrParam.ImgType of
        ImgBase64: xObjImage.AddPair('content',AOcrParam.ImgSource);
        ImgUrl:
          begin
            xObjImageSrc := TJSONOBject.Create;
            xObjImageSrc.AddPair('imageUri',AOcrParam.ImgSource);
            xObjImage.AddPair(TJsonPair.Create('source',xObjImageSrc));
          end;
      end;

      case AOcrParam.Features of
        FeaTextDetection: xObjFeatures.AddPair('type','TEXT_DETECTION');
        FeaDocumentTextDetection: xObjFeatures.AddPair('type','DOCUMENT_TEXT_DETECTION');
      end;
      xArrFeatures.AddElement(xObjFeatures);

      xObjRequest.AddPair('image',xObjImage);
      xObjRequest.AddPair('features',xArrFeatures);
      if Length(AOcrParam.Languages) > 0 then
      begin
        xObjContext := TJSONOBject.Create;
        xArrContext := TJSONArray.Create;
        for Ind := Low(AOcrParam.Languages) to High(AOcrParam.Languages) do
          xArrContext.Add(AOcrParam.Languages[Ind]);
        xObjContext.AddPair('languageHints',xArrContext);
        xObjRequest.AddPair('imageContext',xObjContext);
      end;
      xArrRequest.AddElement(xObjRequest);
      xObjMain.AddPair(TJsonPair.Create('requests',xArrRequest));
      xSendJsonStr := xObjMain.ToJSON;
    finally
      FreeAndNil(xObjMain);
    end;
  {$ENDREGION}
  try
    xNetHttp := TNetHTTPRequest.Create(nil);
    xNetClient := TNetHTTPClient.Create(nil);
    xRepStringStream := TStringStream.Create('',TEncoding.UTF8);
    xReqStringStream := TStringStream.Create(xSendJsonStr,TEncoding.UTF8);
    try
      NetCompSettingsSet(xNetHttp,xNetClient);
      SetLength(xNetHeader,1);
      xNetHeader[0].Name := 'Content-Type';
      xNetHeader[0].Value := 'application/json';
      xGetJsonStr := xNetHttp.Post(GetApiUrl(UrlOcr),xReqStringStream,xRepStringStream,xNetHeader).ContentAsString(TEncoding.UTF8);
      xObjGetMain := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(xGetJsonStr),0) as TJSONObject;
      if xObjGetMain.FindValue('responses') <> nil then
      begin
        xArrResponses := xObjGetMain.GetValue<TJSONArray>('responses');
        if xArrResponses[0].FindValue('error') <> nil then
          SetErrorResult(xArrResponses[0].GetValue<TJSONObject>('error').GetValue<String>('message'))
        else
        begin
          xObjFullTextAnnotation := xArrResponses[0].GetValue<TJSONObject>('fullTextAnnotation');
          Result.TextStr := xObjFullTextAnnotation.GetValue<String>('text');
          xArrTextAnnotations := xArrResponses[0].GetValue<TJSONArray>('textAnnotations');
          SetLength(Result.WordArr,xArrTextAnnotations.Count);
          for Ind := 0 to Pred(xArrTextAnnotations.Count) do
            Result.WordArr[Ind] := xArrTextAnnotations[Ind].GetValue<String>('description');
        end
      end
      else if xObjGetMain.FindValue('error') <> nil then
        SetErrorResult(xObjGetMain.GetValue<TJSONObject>('error').GetValue<String>('message'));
    finally
      if xObjGetMain <> nil then
        FreeAndNil(xObjGetMain);
      FreeAndNil(xReqStringStream);
      FreeAndNil(xRepStringStream);
      FreeAndNil(xNetClient);
      FreeAndNil(xNetHttp);
    end;
  except
    on e:Exception do
    begin
      SetErrorResult(e.Message);
    end;
  end;
end;

procedure TSbCloudVision.NetCompSettingsSet(AReq: TNetHTTPRequest; ACli: TNetHTTPClient);
begin
  with ACli do
  begin
    HandleRedirects := True;
    ConnectionTimeout := 10000;
    ContentType := 'application/json';
    AcceptCharSet := 'utf-8';
  end;
  with AReq do
  begin
    Client := ACli;
    ConnectionTimeout := 10000;
  end;
end;

{ TOcrParam }

class operator TOcrParam.Initialize(out Dest: TOcrParam);
begin
  Dest.ImgType := ImgBase64;
  Dest.Features := FeaTextDetection;
  Dest.Languages := [];
  Dest.ImgSource := '';
end;

{ TOcrResult }

class operator TOcrResult.Initialize(out Dest: TOcrResult);
begin
  Dest.Error := False;
  Dest.ErrorStr := '';
  Dest.TextStr := '';
  Dest.WordArr := [];
end;

end.
