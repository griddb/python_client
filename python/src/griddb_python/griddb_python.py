'''
    Copyright (c) 2024 TOSHIBA Digital Solutions Corporation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
'''

import jpype
import sys
import traceback
import ipaddress


if not jpype.isJVMStarted():
    jpype.startJVM()

import jpype.imports

from java.util import Properties
from java.util import ArrayList
from java.util import HashMap
from java.sql  import Timestamp

from java.util import Collections

from org.apache.arrow.memory import RootAllocator
from org.apache.arrow import c

import pyarrow
import pyarrow.jvm

from enum import IntEnum
from functools import singledispatchmethod
from datetime import datetime
from datetime import timedelta
from datetime import timezone

from java.util import Date as JDate
from java.lang import Integer as JInteger
from java.lang import Long as JLong
from java.lang import String as JString
from javax.sql.rowset.serial import SerialBlob

from com.toshiba.mwcloud.gs.arrow.adapter import JavaAPIToArrow
from com.toshiba.mwcloud.gs.arrow.adapter import JavaAPIParameterBinder
from com.toshiba.mwcloud.gs.arrow.adapter import JavaAPIToArrowConfigBuilder
from com.toshiba.mwcloud.gs.arrow.adapter import MultiGetWrapper
from com.toshiba.mwcloud.gs.arrow.adapter import MultiPutWrapper

from com.toshiba.mwcloud.gs import GridStoreFactory as SF
from com.toshiba.mwcloud.gs import GridStore as JStore
from com.toshiba.mwcloud.gs import ContainerInfo as JContainerInfo
from com.toshiba.mwcloud.gs import ColumnInfo as JColumnInfo
from com.toshiba.mwcloud.gs import TimeSeriesProperties as JTimeSeriesProperties
from com.toshiba.mwcloud.gs import Row as JRow
from com.toshiba.mwcloud.gs import GSType as JType
from com.toshiba.mwcloud.gs import IndexInfo as JIndexInfo
from com.toshiba.mwcloud.gs import IndexType as JIndexType
from com.toshiba.mwcloud.gs import Container as JContainer
from com.toshiba.mwcloud.gs import ContainerType as JContainerType
from com.toshiba.mwcloud.gs import AggregationResult as JAggregationResult
from com.toshiba.mwcloud.gs import QueryAnalysisEntry as JQueryAnalysisEntry
from com.toshiba.mwcloud.gs import RowKeyPredicate as JRowKeyPredicate
from com.toshiba.mwcloud.gs import TimestampUtils as JTimestampUtils
from com.toshiba.mwcloud.gs import TimeUnit as JTimeUnit
from com.toshiba.mwcloud.gs import FetchOption as JFetchOption
from com.toshiba.mwcloud.gs import Geometry as JGeometry
CLIENT_VERSION = "Python Client for GridDB V5.8"

import warnings
warnings.filterwarnings(action="ignore", message=r"datetime.datetime.utcfromtimestamp")

JException = jpype.JClass('java.lang.Exception')
JGsException = jpype.JClass('com.toshiba.mwcloud.gs.GSException')
JGsTimeException = jpype.JClass('com.toshiba.mwcloud.gs.GSTimeoutException')

class Type(IntEnum):
    """_summary_

    Args:
        Enum (_type_): _description_

    Returns:
        _type_: _description_
    """
    STRING = 0
    """STRING型
    """

    BOOL = 1
    """BOOL型
    """

    BYTE = 2
    """BYTE型
    """

    SHORT = 3
    """SHORT型
    """

    INTEGER = 4
    """INTEGER型
    """

    LONG = 5
    """LONG型
    """

    FLOAT = 6
    """FLOAT型
    """

    DOUBLE = 7
    """DOUBLE型
    """

    TIMESTAMP = 8
    """TIMESTAMP型
    """

    GEOMETRY = 9
    """GEOMETRY型
    """

    BLOB = 10
    """BLOB型
    """

    @classmethod
    def _convert_to_java(self, ptype:object)->object:
        jtype = None
        if ptype == self.STRING:
            jtype = JType.STRING
        elif ptype == self.BOOL:
            jtype = JType.BOOL
        elif ptype == self.BYTE:
            jtype = JType.BYTE
        elif ptype == self.SHORT:
            jtype = JType.SHORT
        elif ptype == self.INTEGER:
            jtype = JType.INTEGER
        elif ptype == self.LONG:
            jtype = JType.LONG
        elif ptype == self.FLOAT:
            jtype = JType.FLOAT
        elif ptype == self.DOUBLE:
            jtype = JType.DOUBLE
        elif ptype == self.TIMESTAMP:
            jtype = JType.TIMESTAMP
        elif ptype == self.GEOMETRY:
            jtype = JType.GEOMETRY
        elif ptype == self.BLOB:
            jtype = JType.BLOB
        return jtype

    @classmethod
    def _convert_to_python(self, jtype:object)->object:
        pytype = None
        if jtype == JType.STRING:
            pytype = self.STRING
        elif jtype == JType.BOOL:
            pytype = self.BOOL
        elif jtype == JType.BYTE:
            pytype = self.BYTE
        elif jtype == JType.SHORT:
            pytype = self.SHORT
        elif jtype == JType.INTEGER:
            pytype = self.INTEGER
        elif jtype == JType.LONG:
            pytype = self.LONG
        elif jtype == JType.FLOAT:
            pytype = self.FLOAT
        elif jtype == JType.DOUBLE:
            pytype = self.DOUBLE
        elif jtype == JType.TIMESTAMP:
            pytype = self.TIMESTAMP
        elif jtype == JType.GEOMETRY:
            pytype = self.GEOMETRY
        elif jtype == JType.BLOB:
            pytype = self.BLOB
        return pytype

class TypeOption(IntEnum):
    """NOT NULL制約を示します。
    """
    NULLABLE = 2
    """NOT NULL制約を持たないカラムであることを示します。
    """

    NOT_NULL = 4
    """NOT NULL制約を持つカラムであることを示します。
    """

class IndexType(IntEnum):
    """Containerに設定する索引の種別を示します。

        DEFAULTが指定された場合、以下の基準に従い、デフォルト種別の索引が選択されます。

        .. csv-table::
            :header: "カラム型", "コレクションコンテナ", "時系列コンテナ"

            STRING, TREE, TREE
            BOOL, TREE, TREE
            Numeric type, TREE, TREE
            TIMESTAMP, TREE, TREE
            GEOMETRY, SPATIAL, 設定不可
            BLOB, 設定不可, 設定不可
    """
    DEFAULT = -1
    """デフォルトの索引種別を示します。
    """
    TREE = 1
    """ツリー索引を示します。この索引種別は、時系列におけるロウキーと対応するカラムを除く任意の種別のコンテナにおける、STRING/BOOL/BYTE/SHORT/INTEGER/LONG/FLOAT/DOUBLE/TIMESTAMPの型のカラムに対して使用できます。
    """
    SPATIAL = 4
    """空間索引を示します。この索引種別は、コレクションにおけるGEOMETRY型のカラムに対してのみ使用できます。時系列コンテナに対して設定することはできません。
    """

    @classmethod
    def _convert_to_java(self, index_type:object)->JIndexType:
        jix_type = None
        if index_type == IndexType.DEFAULT:
            jix_type = JIndexType.DEFAULT
        elif index_type == IndexType.TREE:
            jix_type = JIndexType.TREE
        elif index_type == IndexType.SPATIAL:
            jix_type = JIndexType.SPATIAL
        return jix_type

    @classmethod
    def _convert_to_python(self, jindex_type:object)->object:
        pyix_type = None
        if jindex_type == JIndexType.DEFAULT:
            pyix_type = IndexType.DEFAULT
        elif jindex_type == JIndexType.TREE:
            pyix_type = IndexType.TREE
        elif jindex_type == JIndexType.SPATIAL:
            pyix_type = IndexType.SPATIAL
        return pyix_type

class ContainerType(IntEnum):
    """コンテナの種別を表します。
    """
    COLLECTION = 0
    """コレクションコンテナ
    """
    TIME_SERIES = 1
    """時系列コンテナ
    """

    @classmethod
    def _convert_to_java(self, pytype:object)->JContainerType:
        jcon_type = None
        if pytype == self.COLLECTION:
            jcon_type = JContainerType.COLLECTION
        elif pytype == self.TIME_SERIES:
            jcon_type = JContainerType.TIME_SERIES
        return jcon_type

    @classmethod
    def _convert_to_python(self, jtype:object)->object:
        con_type = None
        if jtype == JContainerType.COLLECTION:
            con_type = self.COLLECTION
        elif jtype == JContainerType.TIME_SERIES:
            con_type = self.TIME_SERIES
        return con_type

class util(object):
    """ 内部処理用クラス
    """

    @classmethod
    def _conavert_to_python(self, jtype:object, value:any, time_unit:object)->any:
        rc = None
        if value is None:
            rc = None
        elif jtype == JType.BLOB:
            rc = bytearray(value.getBytes(1, jpype.types.JInt(value.length())))
        elif jtype == JType.BOOL:
            rc = bool(value)
        elif jtype == JType.BYTE:
            rc = int(value)
        elif jtype == JType.DOUBLE:
            rc = float(value)
        elif jtype == JType.FLOAT:
            rc = float(value)
        elif jtype == JType.GEOMETRY:
            rc = str(value.toString())
        elif jtype == JType.INTEGER:
            rc = int(value)
        elif jtype == JType.LONG:
            rc = int(value)
        elif jtype == JType.SHORT:
            rc = int(value)
        elif jtype == JType.STRING:
            rc = str(value)
        elif jtype == JType.TIMESTAMP:
            if time_unit == JTimeUnit.MICROSECOND:
                sec = value.getTime() // 1000
                usec = value.getNanos() //1000
                rc = datetime.utcfromtimestamp(sec) + timedelta(microseconds=usec)
            elif time_unit == JTimeUnit.NANOSECOND:
                rc = value
            else:
                rc = datetime.utcfromtimestamp(value.getTime() /1000)
        elif jtype in [
                       JType.BOOL_ARRAY,
                       JType.BYTE_ARRAY,
                       JType.DOUBLE_ARRAY,
                       JType.FLOAT_ARRAY,
                       JType.INTEGER_ARRAY,
                       JType.LONG_ARRAY,
                       JType.SHORT_ARRAY,
                       JType.STRING_ARRAY,
                       JType.TIMESTAMP_ARRAY,
                      ]:
            rc = None
        else:
            raise GSException(f"Unsupported data type. GSType:{jtype}")
        return rc

    @classmethod
    def get_list(self, jrow:object)->list:
        jcon_info = jrow.getSchema()
        rc_list = []
        for col_no in range(jcon_info.getColumnCount()):
            jcol_info = jcon_info.getColumnInfo(col_no)
            jtype = jcol_info.getType()
            value = jrow.getValue(col_no)
            time_unit = None
            if jtype == JType.TIMESTAMP:
                time_unit = jcol_info.getTimePrecision()

            rc = self._conavert_to_python(jtype, value, time_unit)
            rc_list.append(rc)

        return rc_list

    @classmethod
    def get_list_predicate(self, jrkp:object, data_list:list)->list:
        jcon_info = jrkp.getKeySchema()
        rc_list = []
        for col_no in range(jcon_info.getColumnCount()):
            jcol_info = jcon_info.getColumnInfo(col_no)
            jtype = jcol_info.getType()
            value = data_list[col_no]
            time_unit = None
            if jtype == JType.TIMESTAMP:
                time_unit = jcol_info.getTimePrecision()

            rc = self._conavert_to_python(jtype, value, time_unit)
            rc_list.append(rc)
        return rc_list

    @classmethod
    def get_key_list(self, jcon_info:object, key_list:list)->list:
        rc_list = []
        if len(key_list) >  jcon_info.getColumnCount():
            raise GSException("The number of entries in the specified list is exceeded.")

        for col_no, value in enumerate(key_list):
            jcol_info = jcon_info.getColumnInfo(col_no)
            jtype = jcol_info.getType()

            time_unit = None
            if jtype == JType.TIMESTAMP:
                time_unit = jcol_info.getTimePrecision()

            rc = self._conavert_to_python(jtype, value, time_unit)
            rc_list.append(rc)

        return rc_list

    @classmethod
    def convert_data(self, jcon_info:JContainerInfo, col_no:int, value:any)->object:
        
        jcol_info = jcon_info.getColumnInfo(col_no)
        gs_type = jcol_info.getType()

        rc = None
        if value is None:
            rc = None
        elif gs_type == JType.BLOB:
            if isinstance(value, bytearray):
                rc = SerialBlob(jpype.JArray(jpype.types.JByte)(value))
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.BOOL:
            if isinstance(value, bool):
                rc = jpype.types.JBoolean(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.BYTE:
            if type(value) == int:
                rc = jpype.types.JByte(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.SHORT:
            if type(value) == int:
                rc = jpype.types.JShort(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.INTEGER:
            if type(value) == int:
                rc = jpype.types.JInt(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.LONG:
            if type(value) == int:
                rc = jpype.types.JLong(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.FLOAT:
            if isinstance(value, float):
                rc = jpype.types.JFloat(value)
            elif type(value) == int:
                rc = jpype.types.JFloat(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.DOUBLE:
            if isinstance(value, float):
                rc = jpype.types.JDouble(value)
            elif type(value) == int:
                rc = jpype.types.JDouble(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.TIMESTAMP:
            time_unit = jcol_info.getTimePrecision()
            if time_unit in [JTimeUnit.MICROSECOND, JTimeUnit.NANOSECOND]:
                if isinstance(value, Timestamp):
                    rc = value
                elif isinstance(value, datetime):
                    msec = int(value.timestamp() * 1000)
                    timestamp = Timestamp(msec)
                    if time_unit ==  JTimeUnit.MICROSECOND:
                        usec = value.microsecond
                        timestamp.setNanos(usec * 1000)
                    elif time_unit ==  JTimeUnit.NANOSECOND:
                        nano = int(value.timestamp() * 1e9)
                        timestamp.setNanos(nano % 1000000000)
                    rc = timestamp
                else:
                    raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
            else:
                if isinstance(value, datetime):
                    if value.tzinfo is None:
                        value = value.replace(tzinfo=timezone.utc)
                    rc = JDate(int(value.timestamp() * 1000))
                elif isinstance(value, Timestamp):
                    rc = value
                elif isinstance(value, JDate):
                    rc = datetime.utcfromtimestamp(value.getTime() / 1000)
                else:
                    raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.STRING:
            if isinstance(value, str):
                rc = value
            elif isinstance(value, JString):
                rc = str(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        elif gs_type == JType.GEOMETRY:
            if isinstance(value, str):
                rc = JGeometry.valueOf(value)
            else:
                raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        else:
            raise GSException(f"Unsupported data type. GSType:{gs_type} specifiedType:{type(value)}")
        
        return rc

    @classmethod
    def check_type(self, value:any, actual_type_list:any):
        if value is not None:
            safe = False
            if isinstance(actual_type_list, list):
                for actual_type in actual_type_list:
                    if actual_type == int:
                       if type(value) == actual_type:
                           safe = True
                           break
                    else:
                       if isinstance(value, actual_type):
                           safe = True
                           break
            else:
                if actual_type_list == int:
                    if type(value) == actual_type_list:
                        safe = True
                else:
                    if isinstance(value, actual_type_list):
                        safe = True
                
            if not safe:
                specified_type = type(value)
                raise GSException(f"Specified type unmatched (specifiedType={specified_type}, actualType={actual_type_list})")
        
class AggregationResult(object):
    """集計演算の結果を保持します。

    保持する型は、集計演算の種別や集計対象のカラムの型によって決定されます。具体的な規則はTQLの仕様を参照してください。

    取り出しできる型は、保持されている型によって決まります。保持されている型が数値型の場合はfloat型またはint型、TIMESTAMP型の場合はdatetime型またはTimestamp型の値としてのみ取り出しできます。
    """

    def __init__(self, jaggregationResult:object, jcontainer_info):
        """_summary_

        Args:
            jaggregationResult (_type_): _description_
        """
        self._jar = jaggregationResult
        self._jcon_info = jcontainer_info

    def get(self, type:object)->any:
        """指定した型で集計値を取得します。

        指定可能な型はLONG、DOUBLE、TIMESTAMP。
        TIMESTAMP型でナノ秒精度の場合はdatatime型ではなく、Timestamp型で返します。

        パラメータ:
            type (Type): カラム型

        返り値:
            集計値
        """
        rc = None
        try:
            if type == Type.DOUBLE:
                rc = self._jar.getDouble()
            elif type == Type.LONG:
                rc = self._jar.getLong()
            elif type == Type.TIMESTAMP:
                jcol_info = self._jcon_info.getColumnInfo(0)
                if jcol_info.getTimePrecision() in [JTimeUnit.MICROSECOND, JTimeUnit.NANOSECOND]:
                    rc = self._jar.getPreciseTimestamp()
                else:
                    rc = self._jar.getTimestamp()
            return rc
            
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class IndexInfo(object):
    """索引に関する情報を表します。
    """

    def __init__(self, column_name_list:list=None, name:str=None, type=IndexType.DEFAULT):
        """コンストラクタ

        パラメータ:
            column_name_list (list[str]): カラム名の一覧

            name (str): 索引名

            type (IndexType): 索引種別
        """
        util.check_type(column_name_list, list)
        util.check_type(name, str)
        util.check_type(type, IndexType)
    
        try:
            jcol_list = ArrayList()
            for column_name in column_name_list:
                jcol_list.add(column_name)

            self._jix_info = JIndexInfo.createByColumnList(jcol_list, IndexType._convert_to_java(type))
            if name is not None:
                self._jix_info.setName(name)
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
    @property
    def column_name_list(self)->list:
        """カラム名の一覧
        """
        try:
            if self._jix_info is None:
                return None
            else:
                rc_list = []
                for col in self._jix_info.getColumnNameList():
                    rc_list.append(col)
                return rc_list
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
    @property
    def name(self)->str:
        """索引名
        """
        try:
            if self._jix_info is None:
                return None
            else:
                return_name = self._jix_info.getName()
                if return_name is None:
                    return return_name
                else:
                    return str(return_name)
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
    @property
    def type(self)->object:
        """索引種別
        """
        try:
            if self._jix_info is None:
                return None
            else:
                return IndexType._convert_to_python(self._jix_info.getType())
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
class Container(object):
    """同一タイプのロウ集合からなるGridDBの構成要素に対しての、管理機能を提供します。

    GridDB上のスキーマを構成する各カラムは、ロウオブジェクト内のフィールドやメソッド定義と対応関係を持ちます。 1つのコンテナは1つ以上のカラムにより構成されます。

    カラム名の文字種や長さ、カラム数には制限があります。
    また、フィールドの値の表現範囲やサイズにも制限があります。
    詳細は機能リファレンスの「システムの制限値」をご覧ください。

    GridDB上のロウにおけるNULLは、NOT NULL制約が設定されていない限り保持することができます。
    PythonではNoneとして入出力できます。

    トランザクション処理では、デフォルトで自動コミットモードが有効になっています。自動コミットモードでは、変更操作は逐次確定し、明示的に取り消すことができません。手動コミットモードにおいて、このオブジェクトを介した操作によりクラスタノード上でエラーが検出されGSExceptionが送出された場合、コミット前の更新操作はすべて取り消されます。トランザクション分離レベルはREAD COMMITTEDのみをサポートします。ロック粒度は、コンテナの種別によって異なります。

    このContainerの生成後またはトランザクション終了後、最初にロウの更新・追加・削除、ならびに更新用ロック獲得が行われた時点で、新たなトランザクションが開始されます。
    """

    def __init__(self, jstore:object, jcon:object):
        """_summary_

        Args:
            container (object): _description_
        """
        self._jstore = jstore
        self._jcon = jcon

    def abort(self):
        """手動コミットモードにおいて、現在のトランザクションの操作結果を元に戻し、トランザクションを終了します。
        """
        try:
            self._jcon.abort()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def close(self):
        """クローズします。
        """
        try:
            self._jcon.close()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
           
    def commit(self):
        """手動コミットモードにおいて、現在のトランザクションにおける操作結果を確定させ、トランザクションを終了します。
        """
        try:
            self._jcon.commit()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @singledispatchmethod
    def create_index(self, arg, index_type, name):
        """索引を作成します。

        argにカラム名、index_typeに索引種別、nameに索引名を指定することで単一カラムの索引を作成します。
        argに索引情報(IndexInfoオブジェクト)を指定することで複合索引を作成します。

        時系列のロウキー(TIMESTAMP型)には索引を設定できません。

        第一パラメータ(arg)にキーワードパラメータを使うことはできません。

        パラメータ:
            arg (str, IndexInfo): カラム名もしくは索引情報

            index_type (IndexType): 索引種別

            name (str): 索引名
        """
        raise GSException("arg is invalid.")

    @create_index.register
    def _(self, arg:str,
                index_type:IndexType=IndexType.DEFAULT,
                name:str=None):
        """ インデックス名を指定したcreate_index()
        """

        # argのインスタンスをチェックする。

        util.check_type(arg, str)
        util.check_type(index_type, IndexType)
        util.check_type(name, str)

        try:
            jix_info = JIndexInfo.createByColumn(arg, IndexType._convert_to_java(index_type))

            if name is not None:
                jix_info.setName(name)

            self._jcon.createIndex(jix_info)
            
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @create_index.register
    def _(self, arg:IndexInfo,
                index_type:IndexType=IndexType.DEFAULT,
                name:str=None):
        """ IndexInfoを指定したcreate_index()
        """
        # argのインスタンスをチェックする。
        util.check_type(arg, IndexInfo)
        util.check_type(index_type, IndexType)
        util.check_type(name, str)
        
        jix_info = arg._jix_info
        # 指定されたIndexInfoと指定されたIndexTypeの一致を確認
        if IndexType._convert_to_python(jix_info.getType()) != index_type:
            raise GSException("index_type does not match arg content.")

        # 指定されたIndexInfoと指定されたnameの一致を確認
        if (name is not None) and (str(jix_info.getName()) != name):
            raise GSException("name does not match arg content.")

        try:
            self._jcon.createIndex(jix_info)
            
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @singledispatchmethod
    def drop_index(self, arg=None,
        index_type:object=IndexType.DEFAULT,
        name:str=None):
        """索引を削除します。

        argにカラム名、index_typeに索引種別、nameに索引名を指定することで単一カラムの索引を削除します。
        argに索引情報(IndexInfoオブジェクト)を指定することで複合索引を削除します。

        削除対象となる索引が一つも存在しない場合、索引の削除は行われません。

        第一パラメータ(arg)にキーワードパラメータを使うことはできません。

        パラメータ:
            arg (str, IndexInfo): カラム名もしくは索引情報

            index_type (IndexType): 索引種別

            name (str): 索引名
        """
        raise GSException("arg is invalid.")

    @drop_index.register
    def _(self, arg:str,
        index_type:object=IndexType.DEFAULT,
        name:str=None):

        # argのインスタンスをチェックする。
        util.check_type(arg, str)
        util.check_type(index_type, IndexType)
        util.check_type(name, str)
        
        # カラム名とインデックスタイプを指定してdropIndexを発行
        try:

            jix_info = JIndexInfo.createByColumn(arg, IndexType._convert_to_java(index_type))

            if name is not None:
                jix_info.setName(name)
           
            self._jcon.dropIndex(jix_info)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
    @drop_index.register
    def _(self, arg:object,
        index_type:object=IndexType.DEFAULT,
        name:str=None):

        util.check_type(arg, IndexInfo)
        util.check_type(index_type, IndexType)
        util.check_type(name, str)
        
        jix_info = arg._jix_info

        try:
            # 指定されたIndexInfoと指定されたnameの一致を確認
            if name is not None and str(jix_info.getName()) != name:
                raise GSException("name does not match arg content.")

            self._jcon.dropIndex(jix_info)
            
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)


    def flush(self):
        """これまでの更新結果をSSDなどの不揮発性記憶媒体に書き出し、すべてのクラスタノードが突然停止したとしても内容が失われないようにします。

        通常より信頼性が要求される処理のために使用します。ただし、頻繁に実行すると性能低下を引き起こす可能性が高まります。

        書き出し対象のクラスタノードの範囲など、挙動の詳細はGridDB上の設定によって変化します。
        """

        try:
            self._jcon.flush()

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
    def get(self, key:any)->list:
        """指定のロウキーに対応するロウの内容を取得します。

        パラメータ:
            key (int, str, datetime, Timestamp, RowKey): ロウキー

        返り値:
            ロウの内容と対応するlist形式のロウオブジェクト (list)
        """

        try:
            util.check_type(key, [int, str, datetime, Timestamp, RowKey])

            if isinstance(key, RowKey):
                jrow = self._jcon.get(key._jrk)
            else:
                con_jrow = self._jcon.createRow()
                jcon_info = con_jrow.getSchema()
                if not jcon_info.isRowKeyAssigned():
                    raise GSException("key is not defined correctly.")
                jrow = self._jcon.get(util.convert_data(jcon_info, 0, key))
            if jrow is None:
                return None
            else:
                return util.get_list(jrow)
            
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
    @singledispatchmethod
    def multi_put(self, row_list, row_allocator=None):
        """指定のロウオブジェクト集合(もしくはRecordBatchオブジェクト)に基づき、任意個数のロウをまとめて新規作成または更新します。

        手動コミットモードの場合、対象のロウはロックされます。

        row_listにArrow形式のRecordBatchオブジェクトを指定した場合はroot_allocatorにRootAllocatorオブジェクトを指定する必要があります。

        第一パラメータ(row_list)にキーワードパラメータを使うことはできません。

        パラメータ:
            row_list (list, RecordBatch): list形式のロウオブジェクト、もしくはRecordBatchオブジェクト

            root_allocator (RootAllocator): RootAllocatorオブジェクト
        """
        raise GSException("row_list value specified is incorrect.")

    @multi_put.register
    def _(self, row_list:list, root_allocator:object=None):
        """ row_listにlistを指定されたときのmulti_put()
        """
        # row_listのデータ型をチェックする
        util.check_type(row_list, list)
       
        try:
            jrow_list = ArrayList()
            for row in row_list:
                jrow = self._jcon.createRow()
                jcon_info = jrow.getSchema()
                for col_no, col in enumerate(row):
                    value = util.convert_data(jcon_info, col_no, col)
                    jrow.setValue(col_no, value)
                jrow_list.add(jrow)

            self._jcon.put(jrow_list)
            
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            

    @multi_put.register
    def _(self, row_list:object, root_allocator:object=None):
        """ RecordBatchを指定されたときのmulti_put()
        """
        # row_listのデータ型をチェックする
        util.check_type(row_list, pyarrow.lib.RecordBatch)
        util.check_type(root_allocator, RootAllocator)
        
        if root_allocator is None:
            raise GSException("Error in root_allocator specification.")
            
        root = root_allocator 

        try:
            c_schema = c.ArrowSchema.allocateNew(root_allocator)
            c_array = c.ArrowArray.allocateNew(root_allocator)
            row_list._export_to_c(c_array.memoryAddress(), c_schema.memoryAddress())
            sc_root = c.Data.importVectorSchemaRoot(root_allocator, c_array, c_schema, None)
            binder = JavaAPIParameterBinder.builder(self._jcon, sc_root).bindAll().build()
            self._jcon.put(binder.getList())

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def put(self, row:list)->bool:
        """ロウを新規作成または更新します。

        ロウキーに対応するカラムが存在する場合、ロウキーとコンテナの状態を基に、ロウを新規作成するか、更新するかを決定します。この際、対応するロウがコンテナ内に存在しない場合は新規作成、存在する場合は更新します。

        ロウキーに対応するカラムを持たない場合、常に新規のロウを作成します。

        手動コミットモードの場合、対象のロウがロックされます。

        パラメータ:
            row (list): 新規作成または更新するロウの内容と対応するlist形式のロウオブジェクト

        返り値:
            ロウキーと一致するロウが存在したかどうか (bool)
        """

        # rowの値ををJavaのArrayList[Rowオブジェクト]に変換

        util.check_type(row, list)
        try:
            jrow = self._jcon.createRow()
            jcon_info = jrow.getSchema()
            for col_no, col in enumerate(row):
                value = util.convert_data(jcon_info, col_no, col)
                jrow.setValue(col_no, value)

            return self._jcon.put(jrow)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def query(self, query_string:str)->object:
        """指定のTQL文を実行するためのクエリを作成します。

        パラメータ:
            query_string (str): TQL文

        返り値:
            Queryオブジェクト (Query)
        """

        util.check_type(query_string, str)
        try:
            jquery = self._jcon.query(query_string, None)
            return Query(jquery)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def remove(self, key:object)->bool:
        """指定のロウキーに対応するロウを削除します。

        手動コミットモードの場合、対象のロウはロックされます。

        パラメータ:
            key (int, str, datetime, Timestamp, RowKey): ロウキー

        返り値:
            対応するロウが存在したかどうか (bool)
        """
        util.check_type(key, [int, str, datetime, Timestamp, RowKey])
        try:
            if isinstance(key, RowKey):
                self._jcon.remove(key._jrow)
            else:
                con_jrow = self._jcon.createRow()
                jcon_info = con_jrow.getSchema()
                if not jcon_info.isRowKeyAssigned():
                     raise GSException("key is not defined correctly.")
                return self._jcon.remove(util.convert_data(jcon_info, 0, key))

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def set_auto_commit(self, enabled:bool):
        """コミットモードの設定を変更します。

        自動コミットモードでは、直接トランザクション状態を制御できず、変更操作が逐次コミットされます。自動コミットモードが有効でない場合、すなわち手動コミットモードの場合は、直接commit()を呼び出すかトランザクションがタイムアウトしない限り、このコンテナ内で同一のトランザクションが使用され続け、変更操作はコミットされません。

        自動コミットモードが無効から有効に切り替わる際、未コミットの変更内容は暗黙的にコミットされます。コミットモードに変更がない場合、トランザクション状態は変更されません。

        パラメータ:
            enabled (bool): 自動コミットモードが有効か否か
        """
        util.check_type(enabled, bool)
        try:
            self._jcon.setAutoCommit(enabled)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
    @property
    def type(self)->int:
        """コンテナ型
        """
        try:
            return ContainerType._convert_to_python(self._jcon.getType())

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)
            
class ContainerInfo(object):
    """コンテナに関する情報を表します。
    """

    def __init__(self,
                name:str,
                column_info_list:list,
                type:object=ContainerType.COLLECTION,
                row_key:bool=True,
                row_key_column_list:list=None):
        """コンストラクタ

        パラメータ:
            name (str): コンテナ名

            column_info_list (list[str, Type, TypeOption], list[dict]): カラム情報のリスト。TypeOptionは省略可能。dict形式の場合は"name","type","option","time_unit"で指定する。

            type (ContainerType): コンテナの種別

            row_key (bool): ロウキーに対応するカラムの有無。単一カラムからなるロウキーを持つ場合はtrue、持たない場合はfalse

            row_key_column_list (list[str]): ロウキーを構成するカラム名の一覧
        """

        util.check_type(name, [str, JContainerInfo])
        util.check_type(column_info_list, list)
        util.check_type(type, ContainerType)
        util.check_type(row_key, bool)
        util.check_type(row_key_column_list, list)

        # Java ContainerInfoを指定されたときの処理
        if isinstance(name, JContainerInfo):
            self._jcon_info = name
            return

        try:

            # Java ContainerInfoが省略されたの処理(各引数でJava ContainerInfoを作成)
            col_name_list = []
            jcol_info_list = []
            for column_info in column_info_list:
                if isinstance(column_info, list):
                    # カラム情報がList指定の処理
                    jcol_info = JColumnInfo(str(column_info[0]), Type._convert_to_java(column_info[1]))
                    col_name_list.append(str(column_info[0]))
                    if len(column_info) > 2:
                        jbuilder = JColumnInfo.Builder(jcol_info)
                        if column_info[2] == TypeOption.NOT_NULL:
                            jbuilder.setNullable(True)
                        jcol_info = jbuilder.toInfo()
                    jcol_info_list.append(jcol_info)
                else:
                    # カラム情報がdict指定の処理
                    jcol_info = JColumnInfo(column_info["name"], Type._convert_to_java(column_info["type"]))
                    col_name_list.append(column_info["name"])
                    if "time_unit" in column_info:
                        jbuilder = JColumnInfo.Builder(jcol_info)
                        if column_info["time_unit"] == TimeUnit.MICROSECOND:
                            jbuilder.setTimePrecision(JTimeUnit.MICROSECOND)
                        elif column_info["time_unit"] == TimeUnit.MILLISECOND:
                            jbuilder.setTimePrecision(JTimeUnit.MILLISECOND)
                        elif column_info["time_unit"] == TimeUnit.NANOSECOND:
                            jbuilder.setTimePrecision(JTimeUnit.NANOSECOND)
                        else:
                            raise GSException("time_unit invalid.")

                        jcol_info = jbuilder.toInfo()
                    elif "option" in column_info:
                        if column_info["option"] == TypeOption.NULLABLE:
                            jbuilder = JColumnInfo.Builder(jcol_info)
                            jbuilder.setNullable(True)
                            jcol_info = jbuilder.toInfo()
                        elif column_info["option"] != TypeOption.NOT_NULL:
                            raise GSException("Option invalid.")
                    jcol_info_list.append(jcol_info)

            in_list = ArrayList()
            for item in jcol_info_list:
                in_list.add(item)

            if row_key_column_list is None:
                self._jcon_info=JContainerInfo(name, ContainerType._convert_to_java(type), in_list, row_key)
            else:
                jcol_list = ArrayList()
                for col in row_key_column_list:
                    if col in col_name_list:
                        jcol_list.add(JInteger(col_name_list.index(col)))
                    else: 
                        raise GSException("There is an error in the column name in row_key_column_list")
                    
                    Collections.sort(jcol_list)

                self._jcon_info=JContainerInfo(name, ContainerType._convert_to_java(type), in_list, jcol_list)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def column_info_list(self)->list:
        """カラム情報のリスト(dict形式を利用しない場合)
        """
        try:
            column_list = []
            for num in range(self._jcon_info.getColumnCount()):
                jcol_info = self._jcon_info.getColumnInfo(num)
                if not jcol_info.getTimePrecision() in [JTimeUnit.MILLISECOND, None]:
                    return None
 
                column_info =   [
                                str(jcol_info.getName()),
                                Type._convert_to_python(jcol_info.getType()),
                                ]
                if jcol_info.getNullable():
                    column_info.append(TypeOption.NOT_NULL)
                else:
                    column_info.append(TypeOption.NULLABLE)
                column_list.append(column_info)
            return column_list

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def column_info_list_dict(self)->list:
        """カラム情報のリスト(dict形式を利用する場合)
        """
        try:
            column_dict = []
            for num in range(self._jcon_info.getColumnCount()):
                jcol_info = self._jcon_info.getColumnInfo(num)
                column_info = {
                    "name" : str(jcol_info.getName()),
                    "type" : Type._convert_to_python(jcol_info.getType())
                }

                if jcol_info.getNullable():
                    column_info["option"] = TypeOption.NOT_NULL
                else:
                    column_info["option"] = TypeOption.NULLABLE

                time_unit = jcol_info.getTimePrecision()
                if time_unit == JTimeUnit.MILLISECOND:
                    column_info["time_unit"] = TimeUnit.MILLISECOND
                elif time_unit == JTimeUnit.NANOSECOND:
                    column_info["time_unit"] = TimeUnit.NANOSECOND
                else:
                    column_info["time_unit"] = TimeUnit.MICROSECOND

            return column_dict

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def name(self)->str:
        """コンテナ名
        """
        try:
            return_name = self._jcon_info.getName()
            if return_name is None:
                return return_name
            else:
                return str(return_name)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def row_key(self)->bool:
        """複合ロウキーが設定されていない場合に限定し、ロウキーに対応するカラムの有無を表します。
        """
        try:
            return self._jcon_info.isRowKeyAssigned()

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def row_key_column_list(self)->list:
        """ロウキーを構成するカラム名の一覧 (list[str])
        """
        try:
            col_no_list = self._jcon_info.getRowKeyColumnList()
            col_name_list = []
            for col_no in col_no_list:
                col_name_list.append(str(self._jcon_info.getColumnInfo(col_no).getName()))
            return col_name_list

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def type(self)->object:
        """コンテナの種別
        """
        try:
            return ContainerType._convert_to_python(self._jcon_info.getType())

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class GSException(Exception):
    """GridDB機能の処理中に発生した例外状態を示します。
    """
    def __init__(self, message, jex:object=None):
        
        super().__init__(message)
        self._message = message
        self._traceback_info = None
        self._jtraceback = None
        self._is_jex = False
        self._jex = jex
        self._is_timeout = False

        self._traceback = traceback.format_exc()
        
        if jex is not None:
            if isinstance(jex, JGsException):
                self._is_jex = True
                self._jex = jex
                if self._jex is not None:
                    self._jtraceback = self._jex.getStackTrace()
            elif isinstance(jex, JGsTimeException):
                self._is_jex = True
                self._jex = jex
                if self._jex is not None:
                    self._jtraceback = self._jex.getStackTrace()
                self._is_timeout = True
            else:
                _, _, tb = sys.exc_info()
                self._traceback_info = traceback.extract_tb(tb)
        else:
            _, _, tb = sys.exc_info()
            self._traceback_info = traceback.extract_tb(tb)
 
    def get_error_code(self, stack_index:int)->int:
        """エラーコードを取得します。

        対応する番号が存在しない場合は0を返します。

        パラメータ:
            stack_index (int): エラースタックのインデックス

        返り値:
            エラーコード (int)
        """
        rc = 0
        if self._is_jex:
            rc = self._jex.getErrorCode()

        return rc

    def get_error_stack_size(self)->int:
        """エラー情報のスタックサイズを返す

            返り値:
                エラー情報を含む場合は1、含まない場合は0 (int)
        """
        rc = 0
        if self._is_jex:
           rc = len(self._jtraceback)       
        else:
           rc = len(self._traceback_info)
 
        return rc

    def get_location(self, stack_index:int)->str:
        """直前のエラーのメッセージの内部モジュールのエラー位置情報を取得します。(Deprecated)

        常に空文字列を返します。

        パラメータ:
            stack_index (int): エラースタックのインデックス

        返り値:
            空文字列 (str)
        """
        return ""

    def get_message(self, stack_index:int)->str:
        """エラーメッセージを取得します。

        パラメータ:
            stack_index (int): エラースタックのインデックス

        返り値:
            エラーメッセージ (str)
        """

        if self._is_jex:
            return str(self._jex.getMessage())
        else:
            return self._traceback

    @property
    def is_timeout(self)->bool:
        """要求した処理が既定の時間内に終了しなかった場合に発生する例外であるか否か
        """
        return self._is_timeout



class PartitionController(object):
    """パーティション状態の取得や操作のためのコントローラです。 

    パーティションとは、データを格納する論理的な領域です。 GridDBクラスタ内のデータ配置に基づいた操作を行うために使用します。
    """
    def __init__(self, jpt_cntl:object):
        self._jpt_cntl = jpt_cntl

    def close(self):
        try:
            self._jpt_cntl.close()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_container_count(self, partition_index:int)->int:
        """指定のパーティションに属するコンテナの総数を取得します。

        コンテナ数を求める際の計算量は、コンテナ数にはおおむね依存しません。

        パラメータ:
            partition_index (int): パーティションインデックス。0以上パーティション数未満の値

        返り値:
            コンテナ数 (int)
        """
        util.check_type(partition_index, int)
        try:
            return self._jpt_cntl.getContainerCount(partition_index)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_container_names(self, partition_index:int, start:int, limit:int=None)->list:
        """パーティションインデックス。0以上パーティション数未満の値

        指定のパーティションについてコンテナの新規作成・構成変更・削除が行われたとしても、該当コンテナを除くとその前後で一覧の取得結果の順序が変わることはありません。それ以外の一覧の順序に関しては不定です。重複する名前が含まれることはありません。

        取得件数の上限が指定された場合、上限を超える場合、後方のものから切り捨てられます。指定条件に該当するものが存在しない場合、空のリストが返却されます。

        パラメータ:
            partition_index (int): パーティションインデックス。0以上パーティション数未満の値

            start (int): 取得範囲の開始位置。0以上の値

            limit (int): 取得件数の上限。指定なしもしくはマイナス値を指定した場合、上限なしとみなされる

        返り値:
            コンテナ名の一覧 (list[str])
        """
        util.check_type(partition_index, int)
        util.check_type(start, int)
        util.check_type(limit, int)

        try:
            if start is not None:
                start = JLong(start)
            if limit is not None:
                if limit > 0:
                    limit = JLong(limit)
                else:
                    limit = None
            jnames = self._jpt_cntl.getContainerNames(partition_index, start, limit)
            name_list = []
            for i in range(jnames.size()):
                name_list.append(str(jnames.get(i)))
            return name_list

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def partition_count(self)->int:
        """対象とするGridDBクラスタのパーティション数を取得します。
        """
        try:
            return self._jpt_cntl.getPartitionCount()

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_partition_index_of_container(self, container_name:str)->int:
        """指定のコンテナ名に対応するパーティションインデックスを取得します。

        一度GridDBクラスタが構築されると、コンテナの所属先のパーティションが変化することはなく、パーティションインデックスも一定となります。指定の名前に対応するコンテナが存在するかどうかは、結果に依存しません。
        
        パーティションインデックスの算出に必要とする情報はキャッシュされ、次にクラスタ障害・クラスタノード障害を検知するまで再びGridDBクラスタに問い合わせることはありません。
        
        パラメータ:
           container_name (str): コンテナ名

        返り値:
           パーティションインデックス (int)
        """
        util.check_type(container_name, str)
        try:
            return int(self._jpt_cntl.getPartitionIndexOfContainer(JString(container_name)))

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)


class Query(object):
    """特定のContainerに対応付けられたクエリを保持し、結果取得方法の設定ならびに実行・結果取得を行う機能を持ちます。
    """
    def __init__(self, jquery:object):
        self._jq = jquery
        self._batch_size = None
        self._root_allocator = None

    def close(self):
        try:
            self._jq.close()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)


    def fetch(self, forUpdate:bool=False)->object:
        """オプションを指定してこのクエリを実行し、実行結果に対応するロウ集合を取得します。

        forUpdateにtrueが指定された場合、取得対象のロウすべてをロックします。ロックすると、対応するトランザクションが有効である間、他のトランザクションからの対象ロウに対する変更操作が阻止されます。対応するコンテナの自動コミットモードが無効の場合のみ、指定できます。

        新たなロウ集合を取得すると、このクエリについて前回実行した結果の RowSetはクローズされます。

        一度に大量のロウを取得しようとした場合、GridDBノードが管理する通信バッファのサイズの上限に到達し、失敗することがあります。上限サイズについては、GridDB機能リファレンスを参照してください。

        パラメータ:
            for_update (bool): trueが指定された場合、取得対象のロウすべてをロックします。

        返り値:
            RowSetオブジェクト (RowSet)
        """
        util.check_type(forUpdate, bool)
        try:
            jrow_set = self._jq.fetch(forUpdate)
            return RowSet(jrow_set, self._batch_size, self._root_allocator)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_row_set(self)->object:
        """Returns RowSet直近に実行した結果のRowSetを取得します。

        一度取得すると、以降新たにこのクエリを実行するまでNoneが返却されるようになります。

        返り値:
            RowSetオブジェクト (RowSet)
        """
        try:
            rc = None
            jrow_set = self._jq.getRowSet()
            if jrow_set is not None:
               rc = RowSet(jrow_set, self._batch_size, self._root_allocator)
            return rc

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def set_fetch_options(self, limit:int=-1, partial:bool=False, batch_size:int=-1, root_allocator:object=None):
        """結果取得に関するオプションを設定します。

        パラメータ:
           limit (int): 取得するロウの数の最大値を設定するために使用します。-1は上限なしを意味します。

           partial (bool): 部分実行モードの設定に使われます。

           batch_size (int)： Arrow形式のRecordBatchオブジェクトを取得する時に使われます。-1は全件を意味します。
           
           root_allocator (RootAllocator)： RootAllocatorオブジェクト 
        """
        util.check_type(limit, int)
        util.check_type(partial, bool)
        util.check_type(batch_size, int)
        util.check_type(root_allocator, RootAllocator)
        try:
            if limit != -1:
                self._jq.setFetchOption(JFetchOption.LIMIT, limit)
            if partial:
                self._jq.setFetchOption(JFetchOption.PARTIAL_EXECUTION, partial)

            self._batch_size = batch_size
            self._root_allocator = root_allocator
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class QueryAnalysisEntry(object):
    """クエリプランならびにクエリ処理解析結果を構成する一連の情報の一つを示します。
    """

    def __init__(self, jqae:object):
        self._jqae = jqae

    def get(self)->list:
        """クエリプランならびにクエリ処理解析結果から構成される情報を返します。

        返り値:
            クエリプランならびにクエリ処理解析結果 (list)
        """
        try:
            explan_list = []
            explan_list.append(self._jqae.getId())
            explan_list.append(self._jqae.getDepth())
            explan_list.append(str(self._jqae.getType()))
            explan_list.append(str(self._jqae.getValueType()))
            explan_list.append(str(self._jqae.getValue()))
            explan_list.append(str(self._jqae.getStatement()))
            return explan_list

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class RowKey(object):
    """複合ロウキーを管理します。

    """
    def __init__(self, jrk:object):
        self._jrk = jrk

    def set(self, row_key_value_list:list):
        """ロウキーを設定します。

        指定可能な値はint、str、datetime、Timestampの型の値。

        パラメータ:
           row_key_value_list (list): ロウキーの値
        """
        util.check_type(row_key_value_list, list)
        try:
            jcon_info = self._jrk.getSchema()
            if len(row_key_value_list) > jcon_info.getColumnCount():
                raise GSException("The number of entries in the specified list is exceeded.")

            for col_no, col in enumerate(row_key_value_list):
                value = util.convert_data(jcon_info, col_no, col)
                self._jrk.setValue(col_no, value)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get(self)->list:
        """ロウキーの値を取得します。

        取得されうる型はint、str、datetime、Timestamp。

        返り値:
           ロウキーの値 (list)
        """
        try:
            return util.get_list(self._jrk) 
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class RowKeyPredicate(object):
    """ロウキーの合致条件を表します。

    GridStore.multiGet(java.util.Map)における取得条件を構成するために使用できます。

    条件の種別として、範囲条件と個別条件の2つの種別があります。両方の種別の条件を共に指定することはできません。条件の内容を何も指定しない場合、対象とするすべてのロウキーに合致することを表します。
    """
    def __init__(self, jrkp:object):
        self._jrkp = jrkp

    def get_distinct_keys(self)->list:
        """個別条件を構成するロウキーの値のリストを取得します。

        取得されうる値の型はint、str、datetime、Timestamp、RowKey。

        返り値:
            個別条件を構成するロウキーの値のリスト (list)
        """
        try:
            keys = self._jrkp.getDistinctKeys()
            rc_list = []
            if keys is None or len(keys) == 0:
               rc_list = None

            for key in keys:
                if isinstance(key, JRow.Key):
                    rc_list.append(util.get_list(key))
                else:
                    rc_list.append(util.get_list_predicate(self._jrkp, [key,]))

            return rc_list

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_range(self)->list:
        """範囲条件の開始位置と終了位置に相当するロウキーの値を取得します。

        取得されうる値の型はint、str、datetime、Timestamp、RowKey。

        返り値:
            範囲条件の開始位置と終了位置に相当するロウキーの値 (list)
        """
        try:
            start_value = self._jrkp.getStart()
            if isinstance(start_value, JRow.Key):
                start_value = RowKey(start_value)
            finish_value = self._jrkp.getFinish()
            if isinstance(finish_value, JRow.Key):
                finish_value = RowKey(finish_value)
            return [start_value, finish_value]

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def key_type(self):
        """合致条件の評価対象とするロウキーの型を取得します。
        """
        try:
            return self.Type._convert_to_python(self._jrkp.getKeyType())

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def set_distinct_keys(self, keys:list):
        """個別条件を構成するロウキーの値のリストを設定します。

        設定可能な値の型はint、str、datetime、Timestamp、RowKey。

        パラメータ:
            keys (list): 個別条件を構成するロウキーの値のlist
        """
        util.check_type(keys, list)
        try:
            for key in keys:
                if isinstance(key, RowKey):
                    self._jrkp.add(key._jrk)
                        
                else:
                    jkey_type = self._jrkp.getKeyType()
                    if jkey_type == JType.STRING:
                        value = key
                    elif jkey_type == JType.INTEGER:
                        value = jpype.types.JInt(key)
                    elif jkey_type == JType.LONG:
                        value = jpype.types.JLong(key)
                    elif jkey_type == JType.TIMESTAMP:
                        if isinstance(key, datetime):
                            if key.tzinfo is None:
                                key = key.replace(tzinfo=timezone.utc)
                            value = JDate(int(key.timestamp() * 1000))
                        elif isinstance(key, Timestamp):
                            value = key
                        else:
                            raise GSException("Key type unsupported")
                    else:
                        raise GSException("Key type unsupported")
                    self._jrkp.add(value)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def set_range(self, start:any, end:any):
        """範囲条件の開始位置と終了位置に相当するロウキーの値を設定します。

        パラメータ:
            start (int, str, datetime, Timestamp, RowKey): 範囲条件の開始位置とするロウキーの値

            end (int, str, datetime, Timestamp, RowKey): 範囲条件の終了位置とするロウキーの値
        """
        util.check_type(start, [int, str, datetime, Timestamp, RowKey])
        try:
            if isinstance(start, RowKey):
                self._jrkp.setStart(start._jrk)
            else:
                self._jrkp.setStart(start)

            if isinstance(end, RowKey):
                self._jrkp.setFinish(end._jrk)
            else:
                self._jrkp.setFinish(end)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class RowSet(object):
    """クエリ実行より求めたロウの集合を管理します。

    ロウ単位・ロウフィールド単位での操作機能を持ち、対象とするロウを指し示すための、ResultSetと同様のカーソル状態を保持します。初期状態のカーソルは、ロウ集合の先頭より手前に位置しています。
    """
    def __init__(self, jrowset:object, batch_size:int, root_allocator:object=None):
        self._jrs = jrowset
        self._batch_size = batch_size
        self._root_allocator = root_allocator
        self._type = None
        self._jit = None
        self._jrow = None

    def __iter__(self):
        return self

    def __next__(self):
        if not self.has_next():
            raise StopIteration()
        return self.next() 

    def close(self):
        try:
            self._jrs.close()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)


    def get_column_names(self)->list:
        """カラム名の一覧を取得します。

        返り値:
            カラム名の一覧 (list[str])
        """
        try:
            con_info = self._jrs.getSchema()
            name_list = []
            for col_no in range(con_info.getColumnCount()):
                col_info = con_info.getColumnInfo(col_no)
                name_list.append(str(col_info.getName()))

            return name_list

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def has_next(self)->bool:
        """現在のカーソル位置を基準として、ロウ集合内に後続のロウが存在するかどうかを取得します。

        返り値:
            現在のカーソル位置を基準として、ロウ集合内に後続のロウが存在するかどうか (bool)
        """
        try:
            return self._jrs.hasNext()

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def next(self)->list:
        """ロウ集合内の後続のロウにカーソル移動し、移動後の位置にあるロウオブジェクトを取得します。

        返り値:
            RowSetから取り出すことのできるオブジェクト (list, AggregationResult, QueryAnalysisEntry)
        """

        try:
            rc = None
            jrow = self._jrs.next()
            
            self._jrow = jrow
            if isinstance(jrow, JAggregationResult):
                self._type = RowSetType.AGGREGATION_RESULT
                rc = AggregationResult(jrow, self._jrs.getSchema())
            elif isinstance(jrow, JQueryAnalysisEntry):
                self._type = RowSetType.QUERY_ANALYSIS
                rc = QueryAnalysisEntry(jrow)
            else:
                self._type = RowSetType.CONTAINER_ROWS
                rc = util.get_list(jrow)

            return rc

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def remove(self):
        """現在のカーソル位置のロウを削除します。

        ロックを有効にして取得したRowSetに対してのみ使用できます。
        """
        try:
            self._jrs.remove()

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def size(self)->int:
        """サイズ、すなわちロウ集合作成時点におけるロウの数
           Query.set_fetch_options()でpartial=Trueが設定された場合は、ロウ数を返しません。
        """
        try:
            return self._jrs.size()

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def next_record_batch(self)->object:
        """カーソル位置から指定件数分のロウ集合をArrow形式のRecordBatchオブジェクトで返す。

        返り値:
            RecordBatchオブジェクト (RecordBatch)
        """
        
        try:
            if self._root_allocator is None:
                raise GSException("root_allocator not specified")

            root = self._root_allocator

            rc = None
            if self._jit is None:
                conInfo = self._jrs.getSchema()
                if conInfo is not None:
                    config_builder = JavaAPIToArrowConfigBuilder()
                    config_builder.setAllocator(root)
                    config_builder.setTargetBatchSize(self._batch_size)
                    
                    self._jit = JavaAPIToArrow.javaAPIToArrowVectorIterator(self._jrs, config_builder.build())
                    if self._jit.hasNext():
                       ro = self._jit.next()
                       ro.contentToTSVString()
                       rb = pyarrow.jvm.record_batch(ro)
                       rc = rb
                    else:
                       self._jit = None
            else:
                if self._jit.hasNext():
                    ro = self._jit.next()
                    ro.contentToTSVString()
                    rb = pyarrow.jvm.record_batch(ro)
                    rc = rb
                else:
                    self._jit = None
            return rc

        except JException as ex:
            if ( ex.message() == "QueryAnalysisEntry is not supported" 
               or ex.message() == "AggregationResult is not supported"):
               raise GSException(ex.message())
            else:
               raise GSException("An exception occurred in GridDB python API", ex)
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def type(self)->object:
        """RowSetから取り出すことのできる内容の種別
           next()実行前はNoneを返します。next()実行後に値が決まります。
        """
        return self._type

    def update(self, row:list):
        """現在のカーソル位置のロウについて、指定のロウオブジェクトを使用してロウキー以外の値を更新します。

        パラメータ:
            row (list): 更新に使われるロウオブジェクト
        """
        util.check_type(row, list)
        try:
            jcon_info = self._jrs.getSchema()
            jrow = self._jrow.createRow()

            for col_no, col in enumerate(row):
                value = util.convert_data(jcon_info, col_no, col)
                jrow.setValue(col_no, value)

            self._jrs.update(jrow)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class RowSetType(IntEnum):
    """RowSetから取り出すことのできる内容の種別を示します。
    """
    CONTAINER_ROWS = 0
    """クエリ実行より求めたロウの集合
    """

    AGGREGATION_RESULT = 1
    """集計演算の結果
    """

    QUERY_ANALYSIS = 2
    """クエリプランならびにクエリ処理解析結果を構成する一連の情報
    """

class Store(object):
    """接続したGridDBシステム内のデータベースに属するデータを操作するための機能を提供します。

    コレクションや時系列といったコンテナの追加・削除・構成変更、ならびに、コンテナを構成するロウの操作機能を提供します。

    コンテナ種別などの違いによらず、1つのデータベースのコンテナ間で、 ASCIIの大文字・小文字表記だけが異なる名前のものを複数定義することはできません。コンテナ名は、ベースコンテナ名単独、もしくは、ベースコンテナ名の後ろにノードアフィニティ名をアットマーク「@」で連結した形式で表記します。その他、コンテナの定義において使用できるコンテナ名の文字種や長さには制限があります。具体的には、GridDB機能リファレンスを参照してください。特に記載のない限り、コンテナ名を指定する操作では、ASCIIの大文字・小文字表記の違いは区別されません。

    各メソッドのスレッド安全性は保証されません。
    """
    def __init__(self, jstore:object):
        self._jstore = jstore

    def close(self):
        try:
            self._jstore.close()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def create_row_key(self, info:object)->RowKey:
        """RowKeyオブジェクトを作成します。

        パラメータ:
            info (ContainerInfo): コンテナ情報

        返り値:
            RowKeyオブジェクト (RowKey)
        """
        try:
            jrk = self._jstore.createRowKey(info._jcon_info)

            return RowKey(jrk)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @singledispatchmethod
    def create_row_key_predicate(self, type)->object:
        """指定のtypeをロウキーの型とする合致条件を作成します。

        合致条件の評価対象とするコンテナは、ロウキーを持ち、かつ、そのロウキーの型は指定のtypeと同一の型でなければなりません。

        第一パラメータ(type)にキーワードパラメータを使いことはできません。

        パラメータ:
            type (Type, RowKey): ロウキーの型

        返り値:
            RowKeyPredicateオブジェクト (RowKeyPredicate)
        """
        raise GSException("type is an invalid data type.")

    @create_row_key_predicate.register
    def _(self, type:Type)->object:
        """typeにTypeが指定された場合のcreate_row_key_predicate
        """
        util.check_type(type, Type)
        try:
            return RowKeyPredicate(JRowKeyPredicate.create(Type._convert_to_java(type)))

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @create_row_key_predicate.register
    def _(self, type:RowKey)->object:
        """typeにRowKeyが指定された場合のcreate_row_key_predicate
        """
        util.check_type(type, RowKey)
        try:
            jcon_info = type._jrk.getSchema()
            return RowKeyPredicate(JRowKeyPredicate.create(jcon_info))

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def drop_container(self, name:str):
        """指定の名前を持つコンテナを削除します。

        削除済みの場合は何も変更しません。

        処理対象のコンテナにおいて実行中のトランザクションが存在する場合、それらの終了を待機してから削除を行います。

        パラメータ:
            name (str): コンテナ名
        """
        util.check_type(name, str)
        try:
            self._jstore.dropContainer(name)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def fetch_all(self, query_list:list):
        """指定された任意個数のQueryについて、可能な限りリクエスト単位を大きくしてクエリ実行とフェッチを行います。

        指定のリストに含まれる各Queryに対して、個別にQuery.fetch() を行った場合と同様にクエリ実行とフェッチを行い、結果のRowSetを設定します。各Queryの実行結果を取り出すには、Query.getRowSet() を使用します。ただし、個別に行う場合と違い、同一の格納先などの可能な限り大きな単位で対象ノードに対しリクエストしようとします。これにより、リストの要素数が多くなるほど、対象ノードとやりとりする回数が削減される可能性が高くなります。リスト内のQueryの実行順序は不定です。

        指定のリストには、このGridStoreオブジェクトを介して得られた、対応するContainerを含めクローズされていないQuery のみを含めることができます。 Query.fetch()と同様、各Queryが持つ最後に生成された RowSetがクローズされます。同一のインスタンスがリストに複数含まれていた場合、それぞれ異なるインスタンスであった場合と同様に振る舞います。

        他のコンテナ・ロウ操作と同様、異なるコンテナ間での整合性は保証されません。したがって、あるコンテナに対する処理の結果は、その処理の開始前に完了した他の操作命令の影響を受けることがあります。

        指定のQueryに対応する各Containerのコミットモードが自動コミットモード、手動コミットモードのいずれであったとしても、使用できます。トランザクション状態はクエリの実行結果に反映されます。正常に操作が完了した場合、トランザクションタイムアウト時間に到達しない限り、対応する各Containerのトランザクションをアボートすることはありません。

        各Queryに対する処理の途中で例外が発生した場合、一部のQueryについてのみ新たなRowSet が設定されることがあります。また、指定のQueryに対応する各Containerの未コミットのトランザクションについては、アボートされることがあります。

        一度に大量のロウを取得しようとした場合、GridDBノードが管理する通信バッファのサイズの上限に到達し、失敗することがあります。上限サイズについては、GridDB機能リファレンスを参照してください。

        パラメータ:
            query_list (list[Query]): 対象Queryオブジェクトのリスト
        """

        util.check_type(query_list, list)
        try:
            jq_list = ArrayList()
            for query in query_list:
                jq_list.add(query._jq)

            self._jstore.fetchAll(jq_list)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_container(self, name:str)->object:
        """コンテナ名からContainerオブジェクトを取得します。

        パラメータ:
            name (str): コンテナ名

        返り値:
            コンテナオブジェクト (Container)。指定した名前のコンテナが存在しない場合はNoneを返します。
        """
        util.check_type(name, str)
        try:
            jcon = self._jstore.getContainer(name)
            if jcon is None:
                return None
            else:
                return Container(self._jstore, jcon)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_container_info(self, name:str)->object:
        """指定の名前のコンテナに関する情報を取得します。

        返却されるContainerInfoに含まれるコンテナ名は、GridDB上に格納されているものが設定されます。したがって、指定したコンテナ名と比較すると、 ASCIIの大文字・小文字表記が異なる場合があります。

        パラメータ:
            name (str): コンテナ名

        返り値:
            ContainerInfoオブジェクト (ContainerInfo)。指定した名前のコンテナが存在しない場合はNoneを返します。
        """
        util.check_type(name, str)
        try:
            jcon_info = self._jstore.getContainerInfo(name)
            return ContainerInfo(jcon_info, [])

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def multi_get(self, container_predicate_map:dict, root_allocator=None)->dict:
        """指定の条件に基づき、任意のコンテナの任意個数・範囲のロウについて、可能な限りリクエスト単位を大きくして取得します。

        指定のdictに含まれる条件に従い、個別にContainer.get(Object) もしくはQuery.fetch()を呼び出した場合と同様に、ロウの内容を取得します。ただし、個別に行う場合と違い、同一の格納先などの可能な限り大きな単位で対象ノードに対しリクエストしようとします。これにより、対象コンテナの総数や条件に合致するロウの総数が多くなるほど、対象ノードとやりとりする回数が削減される可能性が高くなります。

        指定のdictは、コンテナ名をキー、RowKeyPredicateで表現される取得条件を値とする任意個数のエントリから構成されます。同一のRowKeyPredicateインスタンスを複数含めることもできます。また、対象とするコンテナとして、コンテナ種別やカラムレイアウトが異なるものを混在させることができます。ただし、コンテナの構成によっては評価できない取得条件が存在します。具体的な制限については、RowKeyPredicateに対する各種設定機能の定義を参照してください。dictのキーまたは値としてNoneを含めることはできません。

        返却されるdictは、コンテナ名をキー、ロウオブジェクトのリストを値とするエントリにより構成されます。また、返却されるマップには、取得条件として指定したマップに含まれるコンテナ名のうち、リクエスト時点で実在するコンテナに関するエントリのみが含まれます。 ASCIIの大文字・小文字表記だけが異なり同一のコンテナを指すコンテナ名の設定された、複数のエントリが指定のdictに含まれていた場合、返却されるdictにはこれらを1つにまとめたエントリが格納されます。指定のコンテナに対応するロウが1つも存在しない場合、対応するロウオブジェクトのリストは空になります。

        返却されたdictもしくはdictに含まれるリストに対して変更操作を行った場合に、 UnsupportedOperationExceptionなどの実行時例外が発生するかどうかは未定義です。

        他のコンテナ・ロウ操作と同様、異なるコンテナ間での整合性は保証されません。したがって、あるコンテナに対する処理の結果は、その処理の開始前に完了した他の操作命令の影響を受けることがあります。

        一度に大量のロウを取得しようとした場合、GridDBノードが管理する通信バッファのサイズの上限に到達し、失敗することがあります。上限サイズについては、GridDB機能リファレンスを参照してください。

        root_allocatorにRootAllocatorオブジェクトを指定した場合は、コンテナ名をキー、RecordBatchオブジェクトを値とするエントリにより構成されるdictを返却します。

        パラメータ:
            predicate_entry (dict[str, RowKeyPredicate]): 対象とするコンテナの名前と条件からなるdict型データ

            root_allocator (RootAllocator): RootAllocatorオブジェクト

        返り値:
            コンテナの名前とロウオブジェクトのリストからなるdict型データ (dict[str, list], dict[str, RecordBatch])
        """
        util.check_type(container_predicate_map, dict)
        util.check_type(root_allocator, RootAllocator)
        try:
            in_map = HashMap()
            for name, row_key_predicate in container_predicate_map.items():
                in_map.put(name, row_key_predicate._jrkp)

            out_container_map = {}
            if  isinstance(root_allocator, RootAllocator):
                # dict(container_name, RecordBatch)で通知

                multi_get_wrapper =  MultiGetWrapper(self._jstore, in_map, root_allocator)
                for k,v in in_map.items():
                    con_info = v.getKeySchema()
                    col_no = con_info.getColumnCount()
                    for i in range(col_no):
                        col_info = con_info.getColumnInfo(i)

                multi_get_wrapper.execute()
                if multi_get_wrapper.size() ==0:
                    return None

                for container_name in container_predicate_map.keys():
                    root = multi_get_wrapper.get(container_name)
                    record_batch = None
                    if root is not None:
                       record_batch = pyarrow.jvm.record_batch(root)

                    out_container_map[container_name] = record_batch

            else:
                # dict(container_name, list<row>)で通知
                map_row_list = self._jstore.multiGet(in_map)

                out_container_map = {}
                for container_name, jrow_list in map_row_list.items():
                    out_list = []
                    for jrow in jrow_list:
                        out_list.append(util.get_list(jrow))

                    out_container_map[container_name] = out_list

            return out_container_map

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def multi_put(self, container_entry:dict, root_allocator=None):
        """任意のコンテナの任意個数のロウについて、可能な限りリクエスト単位を大きくして新規作成または更新操作を行います。

        指定のdictに含まれる各ロウオブジェクトについて、個別に Container.put(Object)を呼び出した場合と同様に新規作成または更新操作を行います。ただし、個別に行う場合と違い、同一の格納先などの可能な限り大きな単位で対象ノードに対しリクエストしようとします。これにより、対象コンテナの総数や指定のロウオブジェクトの総数が多くなるほど、対象ノードとやりとりする回数が削減される可能性が高くなります。

        指定のdictは、コンテナ名をキー、ロウオブジェクトのリストを値とする任意個数のエントリから構成されます。対象とするコンテナとして、コンテナ種別やカラムレイアウトが異なるものを混在させることができます。ただし、すでに存在するコンテナでなければなりません。dictのキーまたは値としてNoneを含めることはできません。

        各ロウオブジェクトのリストには、対象のコンテナと同一のカラムレイアウトの Rowのみを任意個数含めることができます。現バージョンでは、カラム順序についてもすべて同一でなければなりません。リストの要素としてnullを含めることはできません。

        指定のdictに含まれる各ロウオブジェクトにArrow形式のRecordBatchオブジェクトを指定した場合はroot_allocatorにRootAllocatorオブジェクトを指定する必要があります。

        パラメータ:
            container_entry (dict[str, list], dict[str, RecordBatch]): 対象とするコンテナの名前とロウオブジェクトのリスト(もしくはRecordBatchオブジェクト)からなるdict型データ

            root_allocator (RootAllocator): RootAllocatorオブジェクト
        """
        # chack arg.
        util.check_type(container_entry, dict)
        util.check_type(root_allocator, RootAllocator)

        try:
            row_type = 0
            for value in container_entry.values():
                if isinstance(value, list):
                    if row_type == 1:
                        raise GSException("container_entryの指定に誤りがあります")
                    row_type = 2
                elif isinstance(value, pyarrow.lib.RecordBatch):
                    if row_type == 2:
                        raise GSException("container_entryの指定に誤りがあります")
                    row_type = 1
                else:
                    raise GSException("container_entryの指定に誤りがあります")

            if row_type == 1:
                # RecordBatch指定の処理
                multi_put_wrapper = MultiPutWrapper(self._jstore)

                for container_name, record_batch in container_entry.items():
                    c_schema = c.ArrowSchema.allocateNew(root_allocator)
                    c_array = c.ArrowArray.allocateNew(root_allocator)
                    record_batch._export_to_c(c_array.memoryAddress(), c_schema.memoryAddress())
                    root = c.Data.importVectorSchemaRoot(root_allocator, c_array, c_schema, None)
                    multi_put_wrapper.setRoot(container_name, root)
                
                multi_put_wrapper.execute()

            else:
                # list指定の処理
                jconatiner_map = jpype.JClass("java.util.HashMap")()
                for container_name, row_list in container_entry.items():
                    jcon = self._jstore.getContainer(container_name)
                    jrow = jcon.createRow()
                    jcon_info = jrow.getSchema()
                    
                    jrow_list = ArrayList()
                    for row in row_list:

                        set_jrow = jrow.createRow()
                        for col_no, col in enumerate(row):
                            value = util.convert_data(jcon_info, col_no, col)
                            set_jrow.setValue(col_no, value)
                        jrow_list.add(set_jrow)

                    jconatiner_map.put(container_name, jrow_list)

                self._jstore.multiPut(jconatiner_map)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def put_container(self, info:object, modifiable:bool=False)->object:
        """ContainerInfoを指定して、コンテナを新規作成または変更します。

        パラメータ:
            info (ContainerInfo): 処理対象のContainerInfoオブジェクト

            modifiable (bool): 既存コンテナのカラムレイアウト変更を許可するかどうか

        返り値:
            コンテナオブジェクト (Container)
        """
        util.check_type(modifiable, bool)

        if info._jcon_info is None:
            return None

        if info.name is None:
            raise GSException("container name is nothing")

        try:
            jcon = self._jstore.putContainer(info.name, info._jcon_info, modifiable)
            return Container(self._jstore, jcon)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    @property
    def partition_info(self)->object:
        """対応するGridDBクラスタについてのPartitionControllerを取得します。
        """
        if self._jstore is None:
            return None

        try:
            jpartition_controller = self._jstore.getPartitionController()
            return PartitionController(jpartition_controller)

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

class StoreFactory(object):
    """GridStoreインスタンスを管理します。

    GridStoreインスタンス共通のクライアント設定や使用済みのコネクションを管理します。

    GridDBにアクセスするためには、このファクトリを介して GridStoreインスタンスを取得する必要があります。

    このクラスの公開メソッドは、すべてスレッド安全です。
    """
    @classmethod
    def get_instance(self)->object:
        """StoreFactoryオブジェクトを取得します。

        返り値:
            StoreFactoryオブジェクト (StoreFactory)
        """
        try:
            return StoreFactory(SF.getInstance())

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def __init__(self, jsf):
        self._jsf = jsf

    def close(self):
        try:
            self._jsf.close()
        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_store(self,
                    host:str=None,
                    port:int=None,
                    cluster_name:str=None,
                    database:str=None,
                    username:str=None,
                    password:str=None,
                    notification_member:str=None,
                    notification_provider:str=None,
                    application_name:str=None,
                    time_zone:str=None,
                    authentication:str=None,
                    ssl_mode:str=None,
                    connection_route:str=None
                    )->object:
        """指定のプロパティを持つStoreオブジェクトを取得します。

        Storeオブジェクトを取得した時点では、各Containerを管理するマスタノード(以下、マスタ)のアドレス探索を必要に応じて行うだけであり、認証処理は行われません。実際に各Containerに対応するノードに接続する必要が生じたタイミングで、認証処理が行われます。

        取得のたびに、新たなStoreオブジェクトが生成されます。異なるStoreオブジェクトならびに関連するオブジェクトに対する操作は、スレッド安全です。すなわち、ある2つのオブジェクトがそれぞれStoreオブジェクトを基にして生成されたものまたはStoreオブジェクトそのものであり、かつ、該当する関連Storeオブジェクトが異なる場合、一方のオブジェクトに対してどのスレッドからどのタイミングでメソッドが呼び出されていたとしても、他方のオブジェクトのメソッドを呼び出すことができます。ただし、Store自体のスレッド安全性は保証されていないため、同一Storeオブジェクトに対して複数スレッドから任意のタイミングでメソッド呼び出しすることはできません。

        パラメータ:
            host (str): マスタ自動検出に用いられる通知情報を受信するためのIPアドレス (IPv4のみ)もしくは接続先ホスト名(IPアドレス)

            port (int): マスタ自動検出に用いられる通知情報を受信するためのポート番号もしくは接続先ポート番号

            cluster_name (str): クラスタ名

            database (str): データベース名

            username (str): ユーザ名

            password (str): パスワード

            notification_member (str): 固定リスト方式を使用して構成されたクラスタに接続する場合に、クラスタノードのアドレス・ポートのリストを"(アドレス1):(ポート1),(アドレス2):(ポート2),..."形式で指定する。

            notification_provider (str):プロバイダ方式を使用して構成されたクラスタに接続する場合に、アドレスプロバイダのURLを指定する。

            application_name (str): アプリケーション名

            time_zone (str): タイムゾーン。TQLでのTIMESTAMP値演算などに使用される。「±hh:mm」または「±hhmm」形式によるオフセット値 (±は+または-、hhは時、 mmは分)、「Z」(+00:00に相当)、「auto」(実行環境に応じ自動設定)のいずれかを指定する。 autoが使用できるのは夏時間を持たないタイムゾーンに限定される。

            authentication (str): 認証種別。"INTERNAL"(内部認証)もしくは"LDAP"(外部認証)を指定する。

            ssl_mode (str): 	クラスタへの接続においてSSLの使用有無の判断に用いられるモード。"DISABLED"(SSLを常に使用しない)、"PREFERRED"(可能な限りSSLを使用する。SSL接続・非SSL接続共に使用できる場合は SSL接続を使用する)もしくは"VERIFY"(SSLを常に使用する。サーバ検証あり)を指定する。

            connection_route (str): クラスタ接続時における通信経路。"PUBLIC"を指定すると、クラスタの外部通信経路が設定されている場合に外部通信経路を経由した接続を行う。省略時は通常のクラスタ通信経路を用いた接続が行われる。外部接続が必要な場合のみ指定する。

        返り値:
            Storeオブジェクト (Store)
        """

        util.check_type(host, str)
        util.check_type(port, int)
        util.check_type(cluster_name, str)
        util.check_type(database, str)
        util.check_type(username, str)
        util.check_type(password, str)
        util.check_type(notification_member, str)
        util.check_type(notification_provider, str)
        util.check_type(time_zone, str)
        util.check_type(authentication, str)
        util.check_type(ssl_mode, str)
        util.check_type(connection_route, str)

        if self._jsf is None:
            raise GSException("get_instance is not running")

        # Check the connection method specification.
        if ((host is not None or port is not None) and
            (notification_member is not None or notification_provider is not None)):
            raise GSException("Connection method is specified incorrectly.")

        try:
            # create properties
            props = Properties()

            if (notification_member is None) and (notification_provider is None):
                # set property for multicast

                if ipaddress.ip_address(host).is_multicast:
                    props.setProperty("notificationAddress", host)
                    if port is not None:
                        props.setProperty("notificationPort", str(port))
                else:
                    props.setProperty("host", host)
                    if port is not None:
                        props.setProperty("port", str(port))
 
            elif notification_member is not None:
                # set property for fixedlist
                props.setProperty("notificationMember", notification_member)

            elif notification_provider is not None:
                # set property for provider
                props.setProperty("notificationProvider", notification_provider)

            # set property for common information
            if cluster_name is not None:
                props.setProperty("clusterName", cluster_name)
            if database is not None:
                props.setProperty("database", database)
            if username is not None:
                props.setProperty("user", username)
            if password is not None:
                props.setProperty("password", password)
            if application_name is not None:
                props.setProperty("applicationName", application_name)
            if time_zone is not None:
                props.setProperty("timeZone", time_zone)
            if authentication is not None:
                props.setProperty("authentication", authentication)
            if ssl_mode is not None:
                props.setProperty("sslMode", ssl_mode)
            if connection_route is not None:
                props.setProperty("connectionRoute", connection_route)

            # connection
            jstore = self._jsf.getGridStore(props)
            store = Store(jstore)
            return store

        except Exception as ex:
            raise GSException("An exception occurred in GridDB python API", ex)

    def get_version(self)->str:
        """このクライアントライブラリのバージョンを取得する

        返り値:
            このクライアントライブラリのバージョン (str)
        """
        return CLIENT_VERSION

class TimeUnit(IntEnum):
    """時系列処理で用いる時間の単位を示します。
    """
    YEAR = 0
    """年
    """
    MONTH = 1
    """月
    """
    DAY = 2
    """日
    """
    HOUR = 3
    """時
    """
    MINUTE = 4
    """分
    """
    SECOND = 5
    """秒
    """
    MILLISECOND = 6
    """ミリ秒
    """
    MICROSECOND = 7
    """マイクロ秒
    """
    NANOSECOND = 8
    """ナノ秒
    """

class TimestampUtils(object):
    """時刻データを操作するためのユーティリティ機能を提供します。
    """
    @classmethod
    def get_time_millis(self, timestamp:any)->int:
        """datetime.timestampからエポックからの経過ミリ秒を取得する

        パラメータ:
            timestamp (float): Python datetimeのtimestamp値

        返り値:
            エポックからの経過ミリ秒 (int)
        """
        return timestamp * 1000

