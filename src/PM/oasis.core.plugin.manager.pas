unit oasis.core.plugin.manager;

interface

uses
  mormot.core.base,
  mormot.core.collections;

type
  IOPlugin = interface;

  IOPluginManager = interface
  ['{F7917846-7D71-4040-9A51-2BF77F96F256}']
    function LoadFile(const FileName: RawUtf8): IOPlugin;
    procedure LoadFiles;
    function GetPluginList: IList<IOPlugin>;
    property Plugins: IList<IOPlugin> read GetPluginList;


  end;

  IOPlugin = interface
  ['{BFC9DFDA-1D20-4C22-AA97-6F0CAACFA82C}']

  end;

implementation

end.
