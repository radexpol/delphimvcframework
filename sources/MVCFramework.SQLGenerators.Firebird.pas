// *************************************************************************** }
//
// Delphi MVC Framework
//
// Copyright (c) 2010-2020 Daniele Teti and the DMVCFramework Team
//
// https://github.com/danieleteti/delphimvcframework
//
// ***************************************************************************
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// ***************************************************************************

unit MVCFramework.SQLGenerators.Firebird;

interface

uses
  System.Rtti,
  System.Generics.Collections,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef,
  MVCFramework.ActiveRecord,
  MVCFramework.Commons,
  MVCFramework.RQL.Parser;

type
  TMVCSQLGeneratorFirebird = class(TMVCSQLGenerator)

  protected
    function GetCompilerClass: TRQLCompilerClass; override;
  public
    function GetSequenceValueSQL(
      const PKFieldName: string; const SequenceName: string; const Step: Integer): string; override;
    function CreateSelectSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateInsertSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateUpdateSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateDeleteSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateDeleteAllSQL(
      const TableName: string): string; override;
    function CreateSelectByPKSQL(
      const TableName: string;
      const Map: TFieldsMap; const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateSQLWhereByRQL(
      const RQL: string; const Mapping: TMVCFieldsMapping;
      const UseArtificialLimit: Boolean = True;
      const UseFilterOnly: Boolean = False): string; override;
    function CreateSelectCount(
      const TableName: string): string; override;
  end;

implementation

uses
  System.SysUtils,
  MVCFramework.RQL.AST2FirebirdSQL;

function TMVCSQLGeneratorFirebird.CreateInsertSQL(const TableName: string; const Map: TFieldsMap;
  const PKFieldName: string; const PKOptions: TMVCActiveRecordFieldOptions): string;
var
  lKeyValue: TPair<TRttiField, TFieldInfo>;
  lSB: TStringBuilder;
  lPKInInsert: Boolean;
begin
  lPKInInsert := (not PKFieldName.IsEmpty) and (not(TMVCActiveRecordFieldOption.foAutoGenerated in PKOptions));
  lPKInInsert := lPKInInsert and (not(TMVCActiveRecordFieldOption.foReadOnly in PKOptions));
  lSB := TStringBuilder.Create;
  try
    lSB.Append('INSERT INTO ' + TableName + '(');
    if lPKInInsert then
    begin
      lSB.Append(PKFieldName + ',');
    end;
    for lKeyValue in Map do
    begin
      if lKeyValue.Value.Writeable then
      begin
        lSB.Append(lKeyValue.Value.FieldName + ',');
      end;
    end;

    lSB.Remove(lSB.Length - 1, 1);
    lSB.Append(') values (');
    if lPKInInsert then
    begin
      lSB.Append(':' + PKFieldName + ',');
    end;
    for lKeyValue in Map do
    begin
      if lKeyValue.Value.Writeable then
      begin
        lSB.Append(':' + lKeyValue.Value.FieldName + ',');
      end;
    end;

    lSB.Remove(lSB.Length - 1, 1);
    lSB.Append(')');

    if TMVCActiveRecordFieldOption.foAutoGenerated in PKOptions then
    begin
      lSB.Append(' RETURNING ' + PKFieldName);
    end;
    Result := lSB.ToString;
  finally
    lSB.Free;
  end;
end;

function TMVCSQLGeneratorFirebird.CreateSelectByPKSQL(
  const TableName: string;
  const Map: TFieldsMap; const PKFieldName: string;
  const PKOptions: TMVCActiveRecordFieldOptions): string;
begin
  Result := CreateSelectSQL(TableName, Map, PKFieldName, PKOptions) + ' WHERE ' +
    PKFieldName + '= :' + PKFieldName; // IntToStr(PrimaryKeyValue);
end;

function TMVCSQLGeneratorFirebird.CreateSelectCount(
  const TableName: string): string;
begin
  Result := 'SELECT count(*) FROM ' + TableName;
end;

function TMVCSQLGeneratorFirebird.CreateSelectSQL(const TableName: string;
  const Map: TFieldsMap; const PKFieldName: string;
  const PKOptions: TMVCActiveRecordFieldOptions): string;
begin
  Result := 'SELECT ' + TableFieldsDelimited(Map, PKFieldName, ',') + ' FROM ' + TableName;
end;

function TMVCSQLGeneratorFirebird.CreateSQLWhereByRQL(
      const RQL: string; const Mapping: TMVCFieldsMapping;
      const UseArtificialLimit: Boolean;
      const UseFilterOnly: Boolean): string;
var
  lFirebirdCompiler: TRQLFirebirdCompiler;
begin
  lFirebirdCompiler := TRQLFirebirdCompiler.Create(Mapping);
  try
    GetRQLParser.Execute(RQL, Result, lFirebirdCompiler, UseArtificialLimit, UseFilterOnly);
  finally
    lFirebirdCompiler.Free;
  end;
end;

function TMVCSQLGeneratorFirebird.CreateUpdateSQL(const TableName: string; const Map: TFieldsMap;
  const PKFieldName: string; const PKOptions: TMVCActiveRecordFieldOptions): string;
var
  lKeyValue: TPair<TRttiField, TFieldInfo>;
begin
  Result := 'UPDATE ' + TableName + ' SET ';
  for lKeyValue in Map do
  begin
    if lKeyValue.Value.Writeable then
    begin
      Result := Result + lKeyValue.Value.FieldName + ' = :' + lKeyValue.Value.FieldName + ',';
    end;
  end;
  Result[Length(Result)] := ' ';
  if not PKFieldName.IsEmpty then
  begin
    Result := Result + ' where ' + PKFieldName + '= :' + PKFieldName;
  end;
end;

function TMVCSQLGeneratorFirebird.GetCompilerClass: TRQLCompilerClass;
begin
  Result := TRQLFirebirdCompiler;
end;

function TMVCSQLGeneratorFirebird.GetSequenceValueSQL(
  const PKFieldName: string; const SequenceName: string; const Step: Integer): string;
begin
  Result := Format('select gen_id(%s,%d) %s from rdb$database', [SequenceName, Step, PKFieldName]);
end;

function TMVCSQLGeneratorFirebird.CreateDeleteAllSQL(
  const TableName: string): string;
begin
  Result := 'DELETE FROM ' + TableName;
end;

function TMVCSQLGeneratorFirebird.CreateDeleteSQL(const TableName: string; const Map: TFieldsMap;
  const PKFieldName: string; const PKOptions: TMVCActiveRecordFieldOptions): string;
begin
  Result := CreateDeleteAllSQL(TableName) + ' WHERE ' + PKFieldName + '=:' + PKFieldName;
end;

initialization

TMVCSQLGeneratorRegistry.Instance.RegisterSQLGenerator('firebird', TMVCSQLGeneratorFirebird);
TMVCSQLGeneratorRegistry.Instance.RegisterSQLGenerator('interbase', TMVCSQLGeneratorFirebird);

finalization

TMVCSQLGeneratorRegistry.Instance.UnRegisterSQLGenerator('firebird');
TMVCSQLGeneratorRegistry.Instance.UnRegisterSQLGenerator('interbase');

end.
