==============================================
GridDB Python Client Library
==============================================

GridDB (https://github.com/griddb/griddb) is Database for IoT with both NoSQL interface and SQL Interface.
This is Python Client Library for GridDB.

GridDB Python Client has been renewed.

New GridDB Python Client is developed using GridDB Java API(Java Client), JPype(https://github.com/jpype-project/jpype) and Apache Arrow(https://arrow.apache.org/).

Installation
=========================

1. Package dependencies
-------------------------

GridDB JavaAPI, GridDB JavaAPI Adapter for Apache Arrow
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Download GridDB JavaAPI(`gridstore.jar`) and GridDB JavaAPI Adapter for Apache Arrow(`gridstore-arrow.jar`) from Maven Central Repository.

* **Example on Linux, MacOS**

  $ curl -L -o gridstore.jar       https://repo1.maven.org/maven2/com/github/griddb/gridstore/5.8.0/gridstore-5.8.0.jar

  $ curl -L -o gridstore-arrow.jar https://repo1.maven.org/maven2/com/github/griddb/gridstore/5.8.0/gridstore-arrow-5.8.0.jar

2. Install griddb_python
-------------------------

Install the griddb_python by this command::

$ python3 -m pip install griddb_python

JPype(https://pypi.org/project/jpype1/) and pyarrow(https://pypi.org/project/pyarrow/) are also installed.