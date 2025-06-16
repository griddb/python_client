from enum import IntEnum

class ContainerType(IntEnum):
    """コンテナの種別を表します。
    """
    
    COLLECTION = 0
    """コレクションコンテナ
    """
    
    TIME_SERIES = 1
    """時系列コンテナ
    """

class IndexType(IntEnum):
    """Containerに設定する索引の種別を示します。
    
       DEFAULTが指定された場合、以下の基準に従い、デフォルト種別の索引が選択されます。

       .. csv-table::
          :header: "カラム型", "コレクションコンテナ", "時系列コンテナ"
          
          STRING, TREE, TREE
          BOOL, TREE, TREE
          数値型, TREE, TREE
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

class Type(IntEnum):
    """GridDB上のフィールド値の型を表します。
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

class TypeOption(IntEnum):
    """NOT NULL制約を示します。
    """
    
    NULLABLE = 2
    """NOT NULL制約を持たないカラムであることを示します。
    """
    
    NOT_NULL = 4
    """NOT NULL制約を持つカラムであることを示します。
    """
    
class AggregationResult(object):
    """集計演算の結果を保持します。
    
    保持する型は、集計演算の種別や集計対象のカラムの型によって決定されます。具体的な規則はTQLの仕様を参照してください。
    
    取り出しできる型は、保持されている型によって決まります。保持されている型が数値型の場合はfloat型またはint型、TIMESTAMP型の場合はdatetime型またはTimestamp型の値としてのみ取り出しできます。
    """

    def get(self, type):
        """指定した型で集計値を取得します。
        
        指定可能な型はLONG、DOUBLE、TIMESTAMP。
        TIMESTAMP型でナノ秒精度の場合はdatatime型ではなく、Timestamp型で返します。

        パラメータ:
           type (Type): カラム型

        返り値:
           集計値
        """

class IndexInfo:
    """索引に関する情報を表します。
    """

    def __init__(self, column_name_list, name=None, type=IndexType.DEFAULT):
        """コンストラクタ
        
        パラメータ:
           column_name_list (list[str]): カラム名の一覧
           
           name (str): 索引名
           
           type (IndexType): 索引種別
        """

    @property
    def column_name_list(self):
        """カラム名の一覧
        """

    @property
    def name(self):
        """索引名
        """

    @property
    def type(self):
        """索引種別
        """

class RowKey(object):
    """ロウキーを保持します。
    """

    def set(self, row_key_value_list):
        """ロウキーの値をリスト形式で設定します。
        
        指定可能な値はint、str、datetime、Timestampの型の値。

        パラメータ:
           row_key_value_list (list): ロウキーの値
        """
        
    def get(self):
        """ロウキーの値をリスト形式で取得します。
        
        取得されうる型はint、str、datetime、Timestamp。

        返り値:
           ロウキーの値 (list)
        """

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

    @property
    def type(self):
        """コンテナの種別
        """

    def create_index(self, arg, index_type=IndexType.DEFAULT, name=None):
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

    def drop_index(self, arg, index_type=IndexType.DEFAULT, name=None):
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
        
    def flush(self):
        """これまでの更新結果をSSDなどの不揮発性記憶媒体に書き出し、すべてのクラスタノードが突然停止したとしても内容が失われないようにします。

        通常より信頼性が要求される処理のために使用します。ただし、頻繁に実行すると性能低下を引き起こす可能性が高まります。

        書き出し対象のクラスタノードの範囲など、挙動の詳細はGridDB上の設定によって変化します。
        """
        
    def put(self, row):
        """ロウを新規作成または更新します。

        ロウキーに対応するカラムが存在する場合、ロウキーとコンテナの状態を基に、ロウを新規作成するか、更新するかを決定します。この際、対応するロウがコンテナ内に存在しない場合は新規作成、存在する場合は更新します。
        
        ロウキーに対応するカラムを持たない場合、常に新規のロウを作成します。

        手動コミットモードの場合、対象のロウがロックされます。

        パラメータ:
           row (list): 新規作成または更新するロウの内容と対応するlist形式のロウオブジェクト

        返り値:
           ロウキーと一致するロウが存在したかどうか (bool)
        """
        
    def query(self, query_string):
        """指定のTQL文を実行するためのクエリを作成します。

        パラメータ:
           query_string (str): TQL文

        返り値:
           Queryオブジェクト (Query)
        """
        
    def abort(self):
        """手動コミットモードにおいて、現在のトランザクションの操作結果を元に戻し、トランザクションを終了します。
        """
        
    def commit(self):
        """手動コミットモードにおいて、現在のトランザクションにおける操作結果を確定させ、トランザクションを終了します。
        """
        
    def set_auto_commit(self, enabled):
        """コミットモードの設定を変更します。

        自動コミットモードでは、直接トランザクション状態を制御できず、変更操作が逐次コミットされます。自動コミットモードが有効でない場合、すなわち手動コミットモードの場合は、直接commit()を呼び出すかトランザクションがタイムアウトしない限り、このコンテナ内で同一のトランザクションが使用され続け、変更操作はコミットされません。

        自動コミットモードが無効から有効に切り替わる際、未コミットの変更内容は暗黙的にコミットされます。コミットモードに変更がない場合、トランザクション状態は変更されません。

        パラメータ:
           enabled (bool): 自動コミットモードが有効か否か
        """
        
    def get(self, key):
        """指定のロウキーに対応するロウの内容を取得します。

        パラメータ:
           key (int, str, datetime, Timestamp, RowKey): ロウキー

        返り値:
           ロウの内容と対応するlist形式のロウオブジェクト (list)
        """
        
    def remove(self, key):
        """指定のロウキーに対応するロウを削除します。

        手動コミットモードの場合、対象のロウはロックされます。

        パラメータ:
           key (int, str, datetime, Timestamp, RowKey): ロウキー

        返り値:
           対応するロウが存在したかどうか (bool)
        """
        
    def multi_put(self, row_list, root_allocator=None):
        """指定のロウオブジェクト集合(もしくはRecordBatchオブジェクト)に基づき、任意個数のロウをまとめて新規作成または更新します。

        手動コミットモードの場合、対象のロウはロックされます。
        
        row_listにArrow形式のRecordBatchオブジェクトを指定した場合はroot_allocatorにRootAllocatorオブジェクトを指定する必要があります。

        第一パラメータ(row_list)にキーワードパラメータを使うことはできません。

        パラメータ:
           row_list (list, RecordBatch): list形式のロウオブジェクト、もしくはRecordBatchオブジェクト
           
           root_allocator (RootAllocator): RootAllocatorオブジェクト 
        """

class QueryAnalysisEntry(object):
    """クエリプランならびにクエリ処理解析結果を構成する一連の情報の一つを示します。
    """

    def get(self):
        """クエリプランならびにクエリ処理解析結果から構成される情報を返します。

        返り値:
           クエリプランならびにクエリ処理解析結果 (list)
        """
        
class GSException(object):
    """GridDB機能の処理中に発生した例外状態を示します。
    """

    @property
    def is_timeout(self):
        """要求した処理が既定の時間内に終了しなかった場合に発生する例外であるか否か
        """
        
    def get_error_stack_size(self):
        """エラー情報のスタックサイズを返す

        返り値:
           エラー情報を含む場合は1、含まない場合は0 (int)
        """

    def get_error_code(self, stack_index):
        """エラーコードを取得します。
        
        対応する番号が存在しない場合は0を返します。
        
        パラメータ:
           stack_index (int): エラースタックのインデックス

        返り値:
           エラーコード (int)
        """

    def get_message(self, stack_index):
        """エラーメッセージを取得します。
        
        パラメータ:
           stack_index (int): エラースタックのインデックス

        返り値:
           エラーメッセージ (str)
        """

    def get_location(self, stack_index):
        """直前のエラーのメッセージの内部モジュールのエラー位置情報を取得します。(Deprecated)

        常に空文字列を返します。
        
        パラメータ:
           stack_index (int): エラースタックのインデックス

        返り値:
           空文字列 (str)
        """
        
class PartitionController(object):
    """パーティション状態の取得や操作のためのコントローラです。 

    パーティションとは、データを格納する論理的な領域です。 GridDBクラスタ内のデータ配置に基づいた操作を行うために使用します。
    """
    
    @property
    def partition_count(self):
        """対象とするGridDBクラスタのパーティション数を取得します。
        """

    def get_container_count(self, partition_index):
        """指定のパーティションに属するコンテナの総数を取得します。

        コンテナ数を求める際の計算量は、コンテナ数にはおおむね依存しません。
        
        パラメータ:
           partition_index (int): パーティションインデックス。0以上パーティション数未満の値

        返り値:
           コンテナ数 (int)
        """

    def get_container_names(self, partition_index, start, limit):
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

    def get_partition_index_of_container(self, container_name):
        """指定のコンテナ名に対応するパーティションインデックスを取得します。

        一度GridDBクラスタが構築されると、コンテナの所属先のパーティションが変化することはなく、パーティションインデックスも一定となります。指定の名前に対応するコンテナが存在するかどうかは、結果に依存しません。
        
        パーティションインデックスの算出に必要とする情報はキャッシュされ、次にクラスタ障害・クラスタノード障害を検知するまで再びGridDBクラスタに問い合わせることはありません。
        
        パラメータ:
           container_name (str): コンテナ名

        返り値:
           パーティションインデックス (int)
        """
        
class Query(object):
    """特定のContainerに対応付けられたクエリを保持し、結果取得方法の設定ならびに実行・結果取得を行う機能を持ちます。
    """

    def fetch(self, for_update=False):
        """オプションを指定してこのクエリを実行し、実行結果に対応するロウ集合を取得します。

        forUpdateにtrueが指定された場合、取得対象のロウすべてをロックします。ロックすると、対応するトランザクションが有効である間、他のトランザクションからの対象ロウに対する変更操作が阻止されます。対応するコンテナの自動コミットモードが無効の場合のみ、指定できます。

        新たなロウ集合を取得すると、このクエリについて前回実行した結果の RowSetはクローズされます。

        一度に大量のロウを取得しようとした場合、GridDBノードが管理する通信バッファのサイズの上限に到達し、失敗することがあります。上限サイズについては、GridDB機能リファレンスを参照してください。

        パラメータ:
           for_update (bool): trueが指定された場合、取得対象のロウすべてをロックします。

        返り値:
           RowSetオブジェクト (RowSet)
        """

    def get_row_set(self):
        """Returns RowSe直近に実行した結果のRowSetを取得します。

        一度取得すると、以降新たにこのクエリを実行するまでNoneが返却されるようになります。
        
        返り値:
           RowSetオブジェクト (RowSet)
        """

    def set_fetch_options(self, limit=-1, partial=False, batch_size=-1, root_allocator=None):
        """結果取得に関するオプションを設定します。
        
        パラメータ:
           limit (int): 取得するロウの数の最大値を設定するために使用します。-1は上限なしを意味します。
           
           partial (bool): 部分実行モードの設定に使われます。
           
           batch_size (int)： Arrow形式のRecordBatchオブジェクトを取得する時に使われます。-1は全件を意味します。
           
           root_allocator (RootAllocator)： RootAllocatorオブジェクト 
        """
        
class RowKeyPredicate(object):
    """ロウキーの合致条件を表します。
    
    GridStore.multiGet(java.util.Map)における取得条件を構成するために使用できます。
    
    条件の種別として、範囲条件と個別条件の2つの種別があります。両方の種別の条件を共に指定することはできません。条件の内容を何も指定しない場合、対象とするすべてのロウキーに合致することを表します。
    """

    @property
    def key_type(self):
        """合致条件の評価対象とするロウキーの型を取得します。
        """
    
    def get_range(self):
        """範囲条件の開始位置と終了位置に相当するロウキーの値を取得します。

        取得されうる値の型はint、str、datetime、Timestamp、RowKey。

        返り値:
           範囲条件の開始位置と終了位置に相当するロウキーの値 (list)
        """
        
    def set_range(self, start, end):
        """範囲条件の開始位置と終了位置に相当するロウキーの値を設定します。

        パラメータ:
           start (int, str, datetime, Timestamp, RowKey): 範囲条件の開始位置とするロウキーの値
           
           end (int, str, datetime, Timestamp, RowKey): 範囲条件の終了位置とするロウキーの値
        """

    def set_distinct_keys(self, keys):
        """個別条件を構成するロウキーの値のリストを設定します。

        設定可能な値の型はint、str、datetime、Timestamp、RowKey。

        パラメータ:
           keys (list): 個別条件を構成するロウキーの値のlist
        """

    def get_distinct_keys(self):
        """個別条件を構成するロウキーの値のリストを取得します。

        取得されうる値の型はint、str、datetime、Timestamp、RowKey。

        返り値:
           個別条件を構成するロウキーの値のリスト (list)
        """
                        
class RowSet(object):
    """クエリ実行より求めたロウの集合を管理します。
    
    ロウ単位・ロウフィールド単位での操作機能を持ち、対象とするロウを指し示すための、ResultSetと同様のカーソル状態を保持します。初期状態のカーソルは、ロウ集合の先頭より手前に位置しています。
    """

    @property
    def type(self):
        """RowSetから取り出すことのできる内容の種別
           next()実行前はNoneを返します。next()実行後に値が決まります。
        """

    @property
    def size(self):
        """サイズ、すなわちロウ集合作成時点におけるロウの数
        """

    def remove(self):
        """現在のカーソル位置のロウを削除します。
        
        ロックを有効にして取得したRowSetに対してのみ使用できます。
        """

    def next(self):
        """ロウ集合内の後続のロウにカーソル移動し、移動後の位置にあるロウオブジェクトを取得します。

        返り値:
           RowSetから取り出すことのできるオブジェクト (list, AggregationResult, QueryAnalysisEntry)
        """
        
    def has_next(self):
        """現在のカーソル位置を基準として、ロウ集合内に後続のロウが存在するかどうかを取得します。

        返り値:
           現在のカーソル位置を基準として、ロウ集合内に後続のロウが存在するかどうか (bool)
        """

    def update(self, row):
        """現在のカーソル位置のロウについて、指定のロウオブジェクトを使用してロウキー以外の値を更新します。

        パラメータ:
           row (list): 更新に使われるロウオブジェクト
        """
       
    def get_column_names(self):
        """カラム名の一覧を取得します。
        
        返り値:
           カラム名の一覧 (list[str])
        """

    def next_record_batch(self):
        """カーソル位置からbatch_size分(Queryオブジェクトで設定)のロウ集合をArrow形式のRecordBatchオブジェクトで返す。

        返り値:
           RecordBatchオブジェクト (RecordBatch)
        """

class Store(object):
    """接続したGridDBシステム内のデータベースに属するデータを操作するための機能を提供します。
    
    コレクションや時系列といったコンテナの追加・削除・構成変更、ならびに、コンテナを構成するロウの操作機能を提供します。
    
    コンテナ種別などの違いによらず、1つのデータベースのコンテナ間で、 ASCIIの大文字・小文字表記だけが異なる名前のものを複数定義することはできません。コンテナ名は、ベースコンテナ名単独、もしくは、ベースコンテナ名の後ろにノードアフィニティ名をアットマーク「@」で連結した形式で表記します。その他、コンテナの定義において使用できるコンテナ名の文字種や長さには制限があります。具体的には、GridDB機能リファレンスを参照してください。特に記載のない限り、コンテナ名を指定する操作では、ASCIIの大文字・小文字表記の違いは区別されません。
    
    各メソッドのスレッド安全性は保証されません。
    """
    
    @property
    def partition_info(self):
        """対応するGridDBクラスタについてのPartitionControllerオブジェクトを取得します。
        """
        
    def put_container(self, info, modifiable=False):
        """ContainerInfoを指定して、コンテナを新規作成または変更します。
        
        パラメータ:
           info (ContainerInfo): 処理対象のContainerInfoオブジェクト
           
           modifiable (bool): 既存コンテナのカラムレイアウト変更を許可するかどうか
           
        返り値:
           コンテナオブジェクト (Container)
        """
        
    def get_container(self, name):
        """コンテナ名からContainerオブジェクトを取得します。
        
        パラメータ:
           name (str): コンテナ名

        返り値:
           コンテナオブジェクト (Container)。指定した名前のコンテナが存在しない場合はNoneを返します。
        """
        
    def drop_container(self, name):
        """指定の名前を持つコンテナを削除します。

        削除済みの場合は何も変更しません。
        
        処理対象のコンテナにおいて実行中のトランザクションが存在する場合、それらの終了を待機してから削除を行います。
        
        パラメータ:
           name (str): コンテナ名
        """

    def get_container_info(self, name):
        """指定の名前のコンテナに関する情報を取得します。
        
        返却されるContainerInfoに含まれるコンテナ名は、GridDB上に格納されているものが設定されます。したがって、指定したコンテナ名と比較すると、 ASCIIの大文字・小文字表記が異なる場合があります。
        
        パラメータ:
           name (str): コンテナ名

        返り値:
           ContainerInfoオブジェクト (ContainerInfo)。指定した名前のコンテナが存在しない場合はNoneを返します。
        """

    def fetch_all(self, query_list):
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

    def multi_put(self, container_entry, root_allocator=None):
        """任意のコンテナの任意個数のロウについて、可能な限りリクエスト単位を大きくして新規作成または更新操作を行います。

        指定のdictに含まれる各ロウオブジェクトについて、個別に Container.put(Object)を呼び出した場合と同様に新規作成または更新操作を行います。ただし、個別に行う場合と違い、同一の格納先などの可能な限り大きな単位で対象ノードに対しリクエストしようとします。これにより、対象コンテナの総数や指定のロウオブジェクトの総数が多くなるほど、対象ノードとやりとりする回数が削減される可能性が高くなります。

        指定のdictは、コンテナ名をキー、ロウオブジェクトのリストを値とする任意個数のエントリから構成されます。対象とするコンテナとして、コンテナ種別やカラムレイアウトが異なるものを混在させることができます。ただし、すでに存在するコンテナでなければなりません。dictのキーまたは値としてNoneを含めることはできません。

        各ロウオブジェクトのリストには、対象のコンテナと同一のカラムレイアウトの Rowのみを任意個数含めることができます。現バージョンでは、カラム順序についてもすべて同一でなければなりません。リストの要素としてnullを含めることはできません。
        
        指定のdictに含まれる各ロウオブジェクトにArrow形式のRecordBatchオブジェクトを指定した場合はroot_allocatorにRootAllocatorオブジェクトを指定する必要があります。

        パラメータ:
           container_entry (dict[str, list], dict[str, RecordBatch]): 対象とするコンテナの名前とロウオブジェクトのリスト(もしくはRecordBatchオブジェクト)からなるdict型データ
           
           root_allocator (RootAllocator): RootAllocatorオブジェクト 
        """

    def multi_get(self, predicate_entry, root_allocator=None):
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

    def create_row_key_predicate(self, type):
        """指定のtypeをロウキーの型とする合致条件を作成します。

        合致条件の評価対象とするコンテナは、ロウキーを持ち、かつ、そのロウキーの型は指定のtypeと同一の型でなければなりません。
        
        第一パラメータ(type)にキーワードパラメータを使いことはできません。

        パラメータ:
           type (Type, RowKey): ロウキーの型

        返り値:
           RowKeyPredicateオブジェクト (RowKeyPredicate)
        """

    def create_row_key(self, info):
        """RowKeyオブジェクトを作成します。

        パラメータ:
           info (ContainerInfo): コンテナ情報

        返り値:
           RowKeyオブジェクト (RowKey)
        """

class StoreFactory(object):
    """GridStoreインスタンスを管理します。

    GridStoreインスタンス共通のクライアント設定や使用済みのコネクションを管理します。

    GridDBにアクセスするためには、このファクトリを介して GridStoreインスタンスを取得する必要があります。

    このクラスの公開メソッドは、すべてスレッド安全です。
    """

    def get_instance():
        """StoreFactoryオブジェクトを取得します。
        
        返り値:
           StoreFactoryオブジェクト (StoreFactory)
        """

    def get_store(self, host=None, port=None, cluster_name=None, database=None, username=None, password=None, notification_member=None, notification_provider=None,
                   application_name=None, time_zone=None, authentication=None, ssl_mode=None, connection_route=None):
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

    def get_version(self):
        """このクライアントライブラリのバージョンを取得する
        
        返り値:
           このクライアントライブラリのバージョン (str)
        """

class ContainerInfo:
    """コンテナに関する情報を表します。
    """

    def __init__(self, name, column_info_list, type=ContainerType.COLLECTION, row_key=True, row_key_column_list=None):
        """コンストラクタ
        
        パラメータ:
           name (str): コンテナ名
           
           column_info_list (list[str, Type, TypeOption], list[dict]): カラム情報のリスト。TypeOptionは省略可能。dict形式の場合は"name","type","option","time_unit"で指定する。
           
           type (ContainerType): コンテナの種別
           
           row_key (bool): ロウキーに対応するカラムの有無。単一カラムからなるロウキーを持つ場合はtrue、持たない場合はfalse
           
           row_key_column_list (list[str]): ロウキーを構成するカラム名の一覧
       """
        
    @property
    def name(self):
        """コンテナ名
        """

    @property
    def column_info_list(self):
        """カラム情報のリスト(dict形式を利用しない場合)
        """

    @property
    def column_info_list_dict(self):
        """カラム情報のリスト(dict形式を利用する場合)
        """

    @property
    def type(self):
        """コンテナの種別
        """
    
    @property
    def row_key(self):
       """複合ロウキーが設定されていない場合に限定し、ロウキーに対応するカラムの有無を表します。
       """

    @property
    def row_key_column_list(self):
        """ロウキーを構成するカラム名の一覧 (list[str])
        """
    
class TimestampUtils():
    """時刻データを操作するためのユーティリティ機能を提供します。
    """

    def get_time_millis(self, timestamp):
       """datetime.timestampからエポックからの経過ミリ秒を取得する
       
        パラメータ:
           timestamp (float): Python datetimeのtimestamp値

        返り値:
           エポックからの経過ミリ秒 (int)
       """
