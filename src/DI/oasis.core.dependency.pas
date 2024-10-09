unit oasis.core.dependency;

interface

uses
  mormot.core.base,
  mormot.core.text,
  mormot.core.collections,
  mormot.core.interfaces;

type
  EDependencyNotFound   = class(ESynException);
  EInvalidFactory       = class(ESynException);
  EDependencyAlias      = class(ESynException);
  ECircularDependency   = class(ESynException);

  IDependencyFactory = interface;
  IDependency = interface;

  TDependencyRec = record
    Factory : IDependencyFactory;
    Instance : IDependency;
    SingleInstance : Boolean;
    Aliased : Boolean;
    ActualServiceName : RawUtf8;
  end;
  PDependencyRec = ^TDependencyRec; 

  IDependency = interface
  ['{874E6D21-B679-4425-911C-6C98E72A2354}']
  end;

  IDependencyContainer = interface
  ['{3A56A5D1-E6D0-4720-890A-90FFF6239059}']
    function Add(const ServiceName: RawUtf8;
      const ServiceFactory: IDependencyFactory): IDependencyContainer;
    function Factory(const ServiceName: RawUtf8;
      const ServiceFactory: IDependencyFactory): IDependencyContainer;
    function Alias(const AliasName: RawUtf8;
      const ServiceName: RawUtf8): IDependencyContainer;
    function Get(const ServiceName: RawUtf8): IDependency;
    property Services[const ServiceName: RawUtf8]: IDependency read Get; default;
    function Has(const ServiceName: RawUtf8): Boolean;
  end;

  IDependencyFactory = interface
  ['{CDEFFCBB-7593-451B-98C7-FE012D3B2F62}']
    function Build(const Container: IDependencyContainer): IDependency;
  end;

  TFactory = class abstract(TInterfacedObject, IDependencyFactory)
  public
    function Build(const Container: IDependencyContainer): IDependency; virtual; abstract;
  end;

  TInjectableObject = class(TInterfacedObject, IDependency)
  end;

  TCircularDepAvoidFactory = class(TInterfacedObject, IDependencyFactory)
  private
    fConstructing: Boolean;
    fServiceName: RawUtf8;
    fActualFactory: IDependencyFactory;
  public
    constructor Create(const ServiceName: RawUtf8;
      const ActualFactory: IDependencyFactory);
    destructor Destroy(); override;
    function Build(const container: IDependencyContainer): IDependency;
  end;

  TDependencyContainer = class(TInterfacedObject, IDependencyContainer)
  private
    fDependencyList: IKeyValue<RawUtf8, PDependencyRec>;
    function AddDependency(const ServiceName: RawUtf8; 
      const ServiceFactory: IDependencyFactory;
      const SingleInstance: Boolean; 
      const Aliased: Boolean; 
      const ActualServiceName: RawUtf8): IDependencyContainer;
    procedure CleanUpDependencies();
    function GetDepRecordOrExcept(const ServiceName : RawUtf8) : Pointer;
    function GetDependency(const ServiceName : RawUtf8;
      const aDepRec : pointer): IDependency;
  public
    constructor Create(const Dependcies: IKeyValue<RawUtf8, PDependencyRec>);
    destructor Destroy; override;
    function Add(const ServiceName: RawUtf8;
      const ServiceFactory: IDependencyFactory): IDependencyContainer;
    function Factory(const ServiceName: RawUtf8;
      const ServiceFactory: IDependencyFactory): IDependencyContainer;
    function Alias(const AliasName: RawUtf8;
      const ServiceName: RawUtf8): IDependencyContainer;
    function Get(const ServiceName: RawUtf8): IDependency;
    property Services[const ServiceName: RawUtf8]: IDependency read Get; default;
    function Has(const ServiceName: RawUtf8): Boolean;
  end;

implementation

resourcestring
  sDependencyNotFound = 'Dependency "%s" not found';
  sInvalidFactory = 'Factory "%s" is invalid';
  sUnsupportedMultiLevelAlias = 'Unsupported multiple level alias "%s" to "%s"';
  sSameAlias = 'Cannot create alias to itself ("%s" to "%s")';
  sErrCircularDependency = 'Circular dependency when creating service "%s"';

{ TDependencyContainer }

constructor TDependencyContainer.Create(
  const Dependcies: IKeyValue<RawUtf8, PDependencyRec>);
begin
  fDependencyList := Dependcies;
end;

destructor TDependencyContainer.Destroy;
begin
  CleanUpDependencies;
  fDependencyList := nil;
  inherited Destroy;
end;

procedure TDependencyContainer.CleanUpDependencies;
begin
  var val: TPair<RawUtf8, PDependencyRec>;
  var dep: PDependencyRec;
  for val in fDependencyList do
  begin    
    dep := val.Value;
    dep.Factory := nil;
    dep.Instance := nil;
    Dispose(dep);
  end;
  fDependencyList.Clear;
end;

function TDependencyContainer.AddDependency(const ServiceName: RawUtf8;
  const ServiceFactory: IDependencyFactory; const SingleInstance,
  Aliased: Boolean; const ActualServiceName: RawUtf8): IDependencyContainer;
begin
  var depRec: PDependencyRec;
  if not fDependencyList.TryGetValue(ServiceName, depRec) then 
  begin
    New(depRec);
    fDependencyList.Add(ServiceName, depRec);
  end;

  var circularDepFactory: IDependencyFactory := 
    TCircularDepAvoidFactory.Create(ServiceName, ServiceFactory);

  depRec.Factory := circularDepFactory;
  depRec.Instance := nil;
  depRec.SingleInstance := SingleInstance;
  depRec.Aliased := Aliased;
  depRec.ActualServiceName := ActualServiceName;
  Result := Self; 
end;

function TDependencyContainer.Add(const ServiceName: RawUtf8;
  const ServiceFactory: IDependencyFactory): IDependencyContainer;
begin
  Result := AddDependency(ServiceName, ServiceFactory, True, False, '');
end;

function TDependencyContainer.Factory(const ServiceName: RawUtf8;
  const ServiceFactory: IDependencyFactory): IDependencyContainer;
begin
  Result := AddDependency(ServiceName, ServiceFactory, False, False, '');
end;

function TDependencyContainer.GetDepRecordOrExcept(
  const ServiceName: RawUtf8): Pointer;
begin
  var aVal: PDependencyRec;
  if not fDependencyList.TryGetValue(ServiceName, aVal) then 
  begin
    raise EDependencyNotFound.CreateFmt(sDependencyNotFound, [ServiceName]);
  end;
  Result := aVal;
end;

function TDependencyContainer.Alias(const AliasName,
  ServiceName: RawUtf8): IDependencyContainer;
begin
  if (AliasName = ServiceName) then
  begin
    raise EDependencyAlias.CreateFmt(sSameAlias, [AliasName, ServiceName]);
  end;

  var aAactualDepRec: PDependencyRec := GetDepRecordOrExcept(ServiceName);
  if aAactualDepRec.Aliased then
  begin
    raise EDependencyAlias.CreateFmt(sSameAlias,
      [AliasName, ServiceName]);
  end;

  Result := AddDependency(AliasName, nil, False, True, ServiceName);
end;

function TDependencyContainer.GetDependency(const ServiceName: RawUtf8;
  const aDepRec: pointer): IDependency;
begin
  var depRec: PDependencyRec := aDepRec;

  if (depRec.Factory = nil) then
  begin
    raise EInvalidFactory.CreateFmt(sInvalidFactory, [ServiceName]);
  end;

  if (depRec^.SingleInstance) then
  begin
    if (depRec^.Instance = nil) then
    begin
      depRec^.Instance := depRec^.Factory.build(self);
    end;
    result := depRec^.Instance;
  end
  else
  begin
    result := depRec^.Factory.Build(self);
  end;
end;

function TDependencyContainer.Get(const ServiceName: RawUtf8): IDependency;
begin
  var depRec: PDependencyRec := GetDepRecordOrExcept(ServiceName);

  if (not depRec.Aliased) then
  begin
    Result := GetDependency(ServiceName, depRec);
  end
  else
  begin
    Result := Get(depRec.ActualServiceName);
  end;
end;

function TDependencyContainer.Has(const ServiceName: RawUtf8): Boolean;
begin
  Result := fDependencyList.ContainsKey(ServiceName);
end;

{ TCircularDepAvoidFactory }

function TCircularDepAvoidFactory.Build(
  const container: IDependencyContainer): IDependency;
begin
  if fConstructing then
  begin
    raise ECircularDependency.CreateFmt(sErrCircularDependency, [fServiceName]);
  end;

  fConstructing := true;
  try
    result := fActualFactory.build(container);
  finally
    fConstructing := false;
  end;
end;

constructor TCircularDepAvoidFactory.Create(const ServiceName: RawUtf8;
  const ActualFactory: IDependencyFactory);
begin
  fServiceName := ServiceName;
  fActualFactory := ActualFactory;
  fConstructing := False;
end;

destructor TCircularDepAvoidFactory.Destroy;
begin
  fActualFactory := nil;
  fConstructing := false;
  inherited Destroy;
end;

end.
