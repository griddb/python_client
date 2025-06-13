GridDB Pythonクライアント

## 概要

GridDB Pythonクライアントをリニューアルしました。

これまではGridDB C API(Cクライアント)経由でサーバへの操作を提供していましたが、
様々な機能強化のために、
[JPype](https://github.com/jpype-project/jpype)を利用してGridDB Java API(Javaクライアント)経由で
サーバへの操作を提供します。

また、大量データ操作を高速化するために、[Apache Arrow](https://arrow.apache.org/)を利用したインタフェースも 提供します。

## 動作環境

以下の環境でPythonクライアントのビルドとサンプルプログラムの実行を確認しています。

    OS: Ubuntu 22.04 (x64) / RockyLinux 9.4 (x64) / Windows 11 (x64) / MacOS 12 (x86_64)
    Python: 3.12
    Java: 8
    GridDB Java API: V5.8 CE
    GridDB Server: V5.8 CE, Ubuntu 22.04 (x64)

## クイックスタート

本リポジトリにはGridDB Pythonクライアント以外に、GridDB JavaAPI Adapter for Apache Arrowも含みます。
GridDB Pythonクライアントを動かすために、GridDB JavaAPI Adapter for Apache Arrowが必要になります。

### 準備

(GridDB JavaAPI Adapter for Apache Arrow)

    $ cd java
    $ mvn install
    $ cd ..

targetフォルダ上に、gridstore-arrow-X.Y.Z.jarファイルが生成されます。

(GridDB Pythonクライアント)

    $ cd python
    $ python -m pip install .
    $ cd ..

[JPype](https://pypi.org/project/jpype1/), [pyarrow](https://pypi.org/project/pyarrow/), GridDB Pythonクライアント(griddb_python)がインストールされます。

### サンプルコードの実行(Ubuntu, RockyLinux, MacOSでの例)

事前に[GridDBサーバ](https://github.com/griddb/griddb)を起動しておく必要があります。

```sh
$ cd sample
```

1. sampleフォルダ上にGridDB Java APIのダウンロード

```sh
$ curl -L -o gridstore.jar https://repo1.maven.org/maven2/com/github/griddb/gridstore/5.8.0/gridstore-5.8.0.jar
```

2. sampleフォルダ上にGridDB JavaAPI Adapter for Apache Arrowの配置

```sh
$ cp ../java/target/gridstore-arrow-X.Y.Z.jar gridstore-arrow.jar
```

3. 実行

```sh
$ python3 sample1.py <GridDB notification address> <GridDB notification port>
    <GridDB cluster name> <GridDB user> <GridDB password>
  --> Person: name=name02 status=False count=2 lob=[65, 66, 67, 68, 69, 70, 71, 72, 73, 74]
```

Pythonプログラムの先頭に以下の記述をしてください。
```sh
import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
```

なお、環境変数CLASSPATHにJava APIのgridstore.jarファイル とGridDB JavaAPI Adapter for Apache Arrowのgridstore-arrow.jar を設定すると、 
「jpype」のインポートやJVMの起動の記述なしで、従来のPythonクライアントと同じ方法(import griddb_python as griddbのみの記述)で使うことができます。

```sh
$ export CLASSPATH=$CLASSPATH:./gridstore.jar:./gridstore-arrow.jar
```
```sh
import griddb_python as griddb
```

## 機能

(利用できる主な機能)
- STRING型, BOOL型, BYTE型, SHORT型, INTEGER型, LONG型, FLOAT型, DOUBLE型, TIMESTAMP型(ミリ秒精度), BLOB型
- キーを使ったデータ登録・取得(Put/Get)
- NoSQLインタフェース用の検索言語TQLによる検索・集計
- MultiPut/Get/Query (バッチ処理)
- 複合ロウキー、複合索引、GEOMETRY型、マイクロ秒・ナノ秒精度のTIMESTAMP型 [Pythonクライアント V5.8以降]
- Apache Arrowを使ったPut/Get/Fetch [Pythonクライアント V5.8以降]
- パーティショニングされたテーブルへの上記操作 [Pythonクライアント V5.8以降]

(Pythonクライアント V0.8対比で利用できない機能)
- 配列型
- 時系列特化の関数(集計、サンプリングなど)
- 暗黙的データ型変換

## コミュニティ
  * Issues  
    質問、不具合報告はissue機能をご利用ください。
  * PullRequest  
    GridDB Contributor License Agreement(CLA_rev1.1.pdf)に同意して頂く必要があります。
    PullRequest機能をご利用の場合はGridDB Contributor License Agreementに同意したものとみなします。

## ライセンス
  GridDB PythonクライアントのライセンスはApache License, version 2.0です。  

## 商標
  Apache Arrow, Arrow are either registered trademarks or trademarks of The Apache Software Foundation in the United States and other countries.
