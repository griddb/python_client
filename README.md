GridDB Python Client

## Overview

GridDB Python Client is developed using GridDB C Client and [SWIG](http://www.swig.org/) (Simplified Wrapper and Interface Generator).  

The new Python Client brings improved usability. 

Main differences to [the old Python Client](https://github.com/griddb/griddb_client) are as follows:
- Put and get row data without C-based methods defined for each data-type
- Array type for GridDB is available
- Connectivity for Pandas library
- Error handling, date and time handling

## Operating environment

Building of the library and execution of the sample programs have been checked in the following environment.

    OS:              CentOS 6.7(x64)
    SWIG:            3.0.12
    GCC:             4.4.7
    Python:          3.6
    GridDB Server and C Client:   4.0 CE / 3.0 CE

## QuickStart
### Preparations

Install SWIG as below.

    $ wget https://sourceforge.net/projects/pcre/files/pcre/8.39/pcre-8.39.tar.gz
    $ tar xvfz pcre-8.39.tar.gz
    $ cd pcre-8.39
    $ ./configure
    $ make
    $ make install

    $ wget https://prdownloads.sourceforge.net/swig/swig-3.0.12.tar.gz
    $ tar xvfz swig-3.0.12.tar.gz
    $ cd swig-3.0.12
    $ ./configure
    $ make
    $ make install

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
2. When you use GridDB V3.0 CE, please replace gridstore.h with gridstoreForV3.0.h on include/ folder and build sources.

## Community

  * Issues  
    Use the GitHub issue function if you have any requests, questions, or bug reports. 
  * PullRequest  
    Use the GitHub pull request function if you want to contribute code.
    You'll need to agree GridDB Contributor License Agreement(CLA_rev1.1.pdf).
    By using the GitHub pull request function, you shall be deemed to have agreed to GridDB Contributor License Agreement.

## License
  
  GridDB Python Client source license is Apache License, version 2.0.
