GridDB Python Client

## Overview

GridDB Python Client has been renewed.

New GridDB Python Client is developed using GridDB Java API(Java Client), [JPype](https://github.com/jpype-project/jpype) and [Apache Arrow](https://arrow.apache.org/).  

## Operating environment

Building of the library and execution of the sample programs have been checked in the following environment.

    OS: Ubuntu 22.04 (x64) / RockyLinux 9.4 (x64) / Windows 11 (x64) / MacOS 12 (x86_64)
    Python: 3.12
    Java: 8
    GridDB Java API: V5.8 CE
    GridDB server: V5.8 CE, Ubuntu 22.04 (x64)

## QuickStart 

This repository includes GridDB Python Client and GridDB JavaAPI Adapter for Apache Arrow.
GridDB Python Client needs GridDB JavaAPI Adapter for Apache Arrow.

### Preparations

(GridDB JavaAPI Adapter for Apache Arrow)

    $ cd java
    $ mvn install
    $ cd ..

The following file is created under `target/` folder. 
- gridstore-arrow-X.Y.Z.jar

(GridDB Python Client)

    $ cd python
    $ python -m pip install .
    $ cd ..
    
[JPype](https://pypi.org/project/jpype1/), [pyarrow](https://pypi.org/project/pyarrow/), GridDB Python Client(griddb_python) are installed.

### How to run sample (on Linux, Ubuntu, MacOS)

Install [GridDB Server](https://github.com/griddb/griddb).  
GridDB Server need to be started in advance.

```sh
$ cd sample
```

1. Download GridDB Java API on sample folder

```sh
$ curl -L -o gridstore.jar https://repo1.maven.org/maven2/com/github/griddb/gridstore/5.8.0/gridstore-5.8.0.jar
```

2. Place GridDB JavaAPI Adapter for Apache Arrow on sample folder

```sh
$ cp ../java/target/gridstore-arrow-X.Y.Z.jar gridstore-arrow.jar
```

3. Run sample

```sh
$ python3 sample1.py <GridDB notification address> <GridDB notification port>
    <GridDB cluster name> <GridDB user> <GridDB password>
  --> Person: name=name02 status=False count=2 lob=[65, 66, 67, 68, 69, 70, 71, 72, 73, 74]
```

Note:

Please insert the following description in python code.
```sh
import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
```
When you set the path of gridstore.jar and gridstore-arrow.jar into the environment variable "CLASSPATH",
You can use GridDB Python Client without "import jpype" and "startJVM()" like old GridDB Python Client.

```sh
$ export CLASSPATH=$CLASSPATH:./gridstore.jar:./gridstore-arrow.jar
```
```sh
import griddb_python as griddb
```

## Function

(Available)
- STRING, BOOL, BYTE, SHORT, INTEGER, LONG, FLOAT, DOUBLE, TIMESTAMP(milli-second), BLOB type for GridDB
- Put single row, get row with key
- Normal query, aggregation with TQL
- Multi-Put/Get/Query (batch processing)
- Compsite RowKey, Composite Index GEOMETRY type and TIMESTAP(micro/nano-second) type [since Python Client V5.8]
- Put/Get/Fetch with Apache Arrow [since Python Client V5.8]
- Operations for Partitioning table [since Python Client V5.8]

(Not available compared to Python Client V0.8)
- Array type for GridDB
- Timeseries-specific function
- Implicit data type conversion

Please refer to the following files for more detailed information.  
- [Python Client API Reference(Japanese)](https://griddb.github.io/python_client/index.html)

Note:
- There are [Jar for GridDB JavaAPI Adapter for Apache Arrow on Maven Central Repository](https://mvnrepository.com/artifact/com.github.griddb/gridstore-arrow) and [Python Client Package on The Python Package Index (PyPI)](https://pypi.org/project/griddb-python/) .

## Community

  * Issues  
    Use the GitHub issue function if you have any requests, questions, or bug reports. 
  * PullRequest  
    Use the GitHub pull request function if you want to contribute code.
    You'll need to agree GridDB Contributor License Agreement(CLA_rev1.1.pdf).
    By using the GitHub pull request function, you shall be deemed to have agreed to GridDB Contributor License Agreement.

## License
  
  GridDB Python Client source license is Apache License, version 2.0.
  
## Trademarks

  Apache Arrow, Arrow are either registered trademarks or trademarks of The Apache Software Foundation in the United States and other countries.
