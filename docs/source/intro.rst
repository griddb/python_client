=============
はじめに
=============

本ドキュメントでは、GridDB Python APIのNoSQLインタフェースについて説明します。

GridDB Python APIのNoSQLインタフェースは、JPype(OSS)を利用してGridDB Java API経由で
サーバへの操作を提供します。

また、大量データ操作を高速化するために、Apache Arrow(OSS)を利用したインタフェースも
提供します。

※ JPype:
    https://jpype.readthedocs.io/en/latest/index.html

- Python からJNI(Java Native Interface)経由で Java アクセスを提供するソフト(OSS)

※ Apahe Arrow:
    https://arrow.apache.org/

- Apacheプロジェクトの1つ。効率的なデータ交換のために設計された、カラム指向のデータフォーマット、ソフト(OSS)

