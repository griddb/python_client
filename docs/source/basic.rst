=============
操作方法
=============

事前処理
===========================

(A)推奨の方法：

事前に以下のインポートとJVMの起動が必要です。

.. code-block:: python

   import jpype
   jpype.startJVM(classpath=['./gridstore.jar', './gridstore-arrow.jar'])
   import griddb_python as griddb

startJVM()メソッドにて、GridDB Java APIのJarファイル(gridstore.jar)とGridDB JavaAPI Adapter for Apache ArrowのJarファイル(gridstore-arrow.jar)をクラスパスに指定します。

(B)従来のPython APIと同じ方法で使う場合：

.. code-block:: python

    import griddb_python as griddb

環境変数CLASSPATHにGridDB Java APIのJarファイル(gridstore.jar)とGridDB JavaAPI Adapter for Apache ArrowのJarファイル(gridstore-arrow.jar)の場所を設定します。
「jpype」のインポートやJVMの起動の記述なしで、従来のPython APIと同じ方法で使うことができます。

(Linux系のOSの場合の設定例)

.. code-block::

    # export CLASSPATH="./gridstore.jar:./gridstore-arrow.jar"

(C)Apache Arrow形式でやり取りする場合：

RootAllocatorオブジェクトを作成して、関連するメソッドに与えてください。

.. code-block:: python

   import jpype
   jpype.startJVM(classpath=['./gridstore.jar', './gridstore-arrow.jar'])
   import griddb_python as griddb
   import sys
   ra =RootAllocator(sys.maxsize)

(D)Python API(SQL)と併用する場合：

「jpype.dbapi2」のインポートを追加してください。

GridDB JDBCドライバのJarファイル(gridstore-jdbc.jar)の場所をクラスパスに追加で指定してください。

.. code-block:: python

   import jpype
   import jpype.dbapi2
   jpype.startJVM(classpath=['./gridstore.jar', './gridstore-arrow.jar', './gridstore-jdbc.jar'])
   import griddb_python as griddb

その他
===========================

Pandasライブラリとやりとりするために以下の操作例をご利用ください。

- Pandas DataFrameオブジェクトによるGridDBへのデータ登録

    例. container.multi_put(df.values.tolist())

- GridDBからPandas DataFrameオブジェクトへのデータ取得

    例. df = pd.DataFrame(list(rowset), colums=rowset.get_column_names())

