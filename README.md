GridDB Python Client

## Overview

GridDB Python Client is developed using GridDB C Client and [SWIG](http://www.swig.org/) (Simplified Wrapper and Interface Generator).  

## Operating environment

Building of the library and execution of the sample programs have been checked in the following environment.

    OS: CentOS 7.6(x64) (GCC 4.8.5)
    SWIG: 3.0.12
    Python: 3.6
    GridDB C client: V4.2 CE(Community Edition)
    GridDB server: V4.2 CE, CentOS 7.6(x64) (GCC 4.8.5)

    OS: Ubuntu 18.04(x64) (gcc 7.3.0)
    SWIG: 3.0.12
    Python: 3.6
    GridDB C client: V4.2 CE (Note: If you build from source code, please use GCC 4.8.5.)
    GridDB server: V4.2 CE, Ubuntu 18.04(x64) (Note: If you build from source code, please use GCC 4.8.5.)
    
    OS: Windows 10(x64) (VS2017)
    SWIG: 3.0.12
    Python: 3.6
    GridDB C client: V4.2 CE
    GridDB server: V4.2 CE, CentOS 7.6(x64) (GCC 4.8.5)

## QuickStart (CentOS, Ubuntu)
### Preparations

Install SWIG as below.

    $ wget https://prdownloads.sourceforge.net/swig/swig-3.0.12.tar.gz
    $ tar xvfz swig-3.0.12.tar.gz
    $ cd swig-3.0.12
    $ ./configure
    $ make
    $ sudo make install
   
    Note: If CentOS, you might need to install pcre in advance.
    $ sudo yum install pcre2-devel.x86_64

Install [GridDB Server](https://github.com/griddb/griddb_nosql) and [C Client](https://github.com/griddb/c_client). (Note: If you build them from source code, please use GCC 4.8.5.) 

Set CPATH and LIBRARY_PATH. 

	export CPATH=$CPATH:<Python header file directory path>

    export LIBRARY_PATH=$LIBRARY_PATH:<C client library file directory path>

### Build and Run 

    1. Execute the command on project directory.

    $ make

    2. Set the PYTHONPATH variable for griddb Python module files.
    
    $ export PYTHONPATH=$PYTHONPATH:<installed directory path>

    3. Import griddb_python in Python.

### How to run sample

GridDB Server need to be started in advance.

    1. Set LD_LIBRARY_PATH

        export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:<C client library file directory path>

    2. The command to run sample

        $ sample/sample1.py <GridDB notification address> <GridDB notification port>
            <GridDB cluster name> <GridDB user> <GridDB password>
          -->Person: name=name02 status=False count=2 lob=[65, 66, 67, 68, 69, 70, 71, 72, 73, 74]

## QuickStart (Windows)

Please refer to [Cmake Build Guide](https://griddb.github.io/python_client/cmake_build_guide.html)

## Function

(available)
- STRING, BOOL, BYTE, SHORT, INTEGER, LONG, FLOAT, DOUBLE, TIMESTAMP, BLOB type for GridDB
- put single row, get row with key
- normal query, aggregation with TQL
- Multi-Put/Get/Query (batch processing)
- Array type for GridDB

(not available)
- GEOMETRY type for GridDB
- timeseries compression
- timeseries-specific function like gsAggregateTimeSeries, gsQueryByTimeSeriesSampling in C client
- trigger, affinity

Please refer to the following files for more detailed information.  
- [Python Client API Reference](https://griddb.github.io/python_client/PythonAPIReference.htm)

Note:
1. The current API might be changed in the next version. e.g. ContainerInfo
2. When you install C Client with RPM or DEB, you don't need to set LIBRARY_PATH and LD_LIBRARY_PATH.
3. There is [Python Client (0.8.2) Package for CentOS on The Python Package Index (PyPI)](https://pypi.org/project/griddb-python/) .

## Community

  * Issues  
    Use the GitHub issue function if you have any requests, questions, or bug reports. 
  * PullRequest  
    Use the GitHub pull request function if you want to contribute code.
    You'll need to agree GridDB Contributor License Agreement(CLA_rev1.1.pdf).
    By using the GitHub pull request function, you shall be deemed to have agreed to GridDB Contributor License Agreement.

## License
  
  GridDB Python Client source license is Apache License, version 2.0.
