GridDB Python Client

## Overview

GridDB Python Client is developed using GridDB C Client and [SWIG](http://www.swig.org/) (Simplified Wrapper and Interface Generator).  

## Operating environment

Building of the library and execution of the sample programs have been checked in the following environment.


    OS: Ubuntu 24.04(x64) (gcc 11)
    SWIG: 4.0.2
    Python: 3.12
    GridDB C client: V5.6 CE
    GridDB server: V5.6 CE

    OS: RockyLinux 9.4(x64) (gcc 11)
    SWIG: 4.0.2
    Python: 3.12
    GridDB C client: V5.6 CE
    GridDB server: V5.6 CE

    OS: Windows 11(x64) (VS2017)
    SWIG: 4.0.2
    Python: 3.12
    GridDB C client: V5.6 CE
    GridDB server: V5.6 CE, Ubuntu 24.04

    OS: MacOS 12
    SWIG: 4.0.2
    Python: 3.12
    GridDB C client: V5.6 CE
    GridDB server: V5.6 CE, Ubuntu 24.04

## QuickStart (CentOS, Ubuntu)
### Preparations

Install SWIG as below.

    $ wget https://github.com/swig/swig/archive/refs/tags/v4.0.2.tar.gz
    $ tar xvfz v4.0.2.tar.gz
    $ cd swig-4.0.2
    $ ./autogen.sh
    $ ./configure
    $ make
    $ sudo make install
   
    Note: If CentOS, you might need to install pcre in advance.
    $ sudo yum install pcre2-devel.x86_64

Install [GridDB Server](https://github.com/griddb/griddb) and [C Client](https://github.com/griddb/c_client). (Note: If you build them from source code, please use GCC 4.8.5.) 

Set CPATH and LIBRARY_PATH. 

	export CPATH=$CPATH:<Python header file directory path>

    export LIBRARY_PATH=$LIBRARY_PATH:<C client library file directory path>

Install Pandas and Numpy as below:

    $ python3 -m pip install numpy
    $ python3 -m pip install pandas

### Build and Run 

    1. Execute the command on project directory.

    $ make

    2. Set the PYTHONPATH variable for griddb Python module files.
    
    $ export PYTHONPATH=$PYTHONPATH:<installed directory path>

    3. Import griddb_python in Python.

### How to run sample

GridDB Server need to be started in advance.

    1. Set LD_LIBRARY_PATH

        $ export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:<C client library file directory path>

    2. The command to run sample

        $ python3 sample/sample1.py <GridDB notification address> <GridDB notification port>
            <GridDB cluster name> <GridDB user> <GridDB password>
          -->Person: name=name02 status=False count=2 lob=[65, 66, 67, 68, 69, 70, 71, 72, 73, 74]

## QuickStart (Windows)

### Using source code

Please refer to [Cmake Build Guide](https://griddb.github.io/python_client/cmake_build_guide.html)

### Using MSI

#### Install Python Client

Install the MSI package, the package is extracted into C:/Program Files/griddb/Python Client/X.X.X folder.

#### Execute a Python client sample program

* Put sample1.py into C:/Program Files/GridDB/Python Client/X.X.X
* Run following command to execute program
    ```
    <PATH_TO>/python.exe sample1.py <GridDB notification address> <GridDB notification port>
            <GridDB cluster name> <GridDB user> <GridDB password>
    ```

Note: X.X.X is the software version.

## QuickStart (MacOS)
### Preparations

Install SWIG as below.

    $ wget https://github.com/swig/swig/archive/refs/tags/v4.0.2.tar.gz
    $ tar xvfz v4.0.2.tar.gz
    $ cd swig-4.0.2
    $ ./autogen.sh
    $ ./configure
    $ make
    $ sudo make install

    Note: If MacOS, you might need to install pcre in advance.
    $ brew install pcre

Install [GridDB Server](https://github.com/griddb/griddb) and [C Client](https://github.com/griddb/c_client). (Note: If you build them from source code, please use clang 11.0.0)

Set CPATH and LIBRARY_PATH.

    export CPATH=$CPATH:<Python header file directory path>

    export LIBRARY_PATH=$LIBRARY_PATH:<C client library file directory path>

Install Pandas and Numpy as below:

    $ python3 -m pip install numpy
    $ python3 -m pip install pandas

### Build and Run

    1. Execute the command on project directory.

    $ make

    2. Set the PYTHONPATH variable for griddb Python module files.

    $ export PYTHONPATH=$PYTHONPATH:<installed directory path>

    3. Import griddb_python in Python.

### How to run sample

GridDB Server need to be started in advance.

    1. Set DYLD_LIBRARY_PATH

        export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}:<C client library file directory path>

    2. The command to run sample

        $ python3 sample/sample1.py <GridDB notification address> <GridDB notification port>
            <GridDB cluster name> <GridDB user> <GridDB password>
          -->Person: name=name02 status=False count=2 lob=[65, 66, 67, 68, 69, 70, 71, 72, 73, 74]

## Function

(available)
- STRING, BOOL, BYTE, SHORT, INTEGER, LONG, FLOAT, DOUBLE, TIMESTAMP, BLOB type for GridDB
- put single row, get row with key
- normal query, aggregation with TQL
- Multi-Put/Get/Query (batch processing)
- Array type for GridDB
- timeseries-specific function, affinity

(not available)
- GEOMETRY type for GridDB

Please refer to the following files for more detailed information.  
- [Python Client API Reference](https://griddb.github.io/python_client/PythonAPIReference.htm)

Note:
1. The current API might be changed in the next version. e.g. ContainerInfo
2. When you install C Client with RPM or DEB, you don't need to set LIBRARY_PATH and LD_LIBRARY_PATH.
3. There is [Python Client Package for only Python 3.10 (Linux, MacOS) on The Python Package Index (PyPI)](https://pypi.org/project/griddb-python/) .

## Community

  * Issues  
    Use the GitHub issue function if you have any requests, questions, or bug reports. 
  * PullRequest  
    Use the GitHub pull request function if you want to contribute code.
    You'll need to agree GridDB Contributor License Agreement(CLA_rev1.1.pdf).
    By using the GitHub pull request function, you shall be deemed to have agreed to GridDB Contributor License Agreement.

## License
  
  GridDB Python Client source license is Apache License, version 2.0.
