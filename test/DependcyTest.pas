unit DependcyTest;

interface

uses
  DUnitX.TestFramework,
  mormot.core.base,
  mormot.core.collections,
  oasis.core.dependency;

type
  ITest1 = interface
  ['{CB1AB272-11DB-45FC-91FE-1F7E3442C78E}']
  end;

  ITest2 = interface
  ['{AEB737F8-7FC5-4C2D-95F4-33FEFF9680EB}']
    function Add(const x, y: Integer): Integer;
  end;

  TTest1Factory = class(TInterfacedObject, IDependencyFactory)
  public
    function Build(const Container: IDependencyContainer): IDependency;
  end;

  TTest1 = class(TInterfacedObject, IDependency, ITest2)
  public
    function Add(const x, y: Integer): Integer;
  end;

  [TestFixture]
  DependencyTest = class
  private
    fContainer: IDependencyContainer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // Sample Methods
    // Simple single Test
    [Test]
    procedure Test1;
    // Test with TestCase Attribute to supply parameters.
    [Test]
    [TestCase('Test 1 + 2','1,2')]
    [TestCase('Test 3 + 4','3,4')]
    procedure Test2(const AValue1 : Integer;const AValue2 : Integer);
  end;

implementation

procedure DependencyTest.Setup;
begin

  fContainer :=
    TDependencyContainer.Create(
      Collections.NewPlainKeyValue<RawUtf8, PDependencyRec>()) as IDependencyContainer;
  fContainer.Add('Test1', TTest1Factory.Create as IDependencyFactory);
end;

procedure DependencyTest.TearDown;
begin
  fContainer := nil;
end;

procedure DependencyTest.Test1;
begin

end;

procedure DependencyTest.Test2(const AValue1 : Integer;const AValue2 : Integer);
begin
  Assert.AreEqual((fContainer['Test1'] as ITest2).Add(AValue1, AValue2), AValue1 + AValue2);
end;

{ TTest1Factory }

function TTest1Factory.Build(
  const Container: IDependencyContainer): IDependency;
begin
  Result := TTest1.Create as IDependency;
end;

{ TTest1 }

function TTest1.Add(const x, y: Integer): Integer;
begin
  Result := x + y;
end;

initialization
  TDUnitX.RegisterTestFixture(DependencyTest);

end.
