unit oasis.core.appsvrc;

interface

uses
  oasis.core.dependency;

type
  IAppServiceProvider = interface
  ['{CBC6750F-7BCB-42AA-9B1B-DFBA1E1DE93E}']
    function GetContainer: IDependencyContainer;
    property Container: IDependencyContainer read GetContainer;

  end;

implementation

end.
