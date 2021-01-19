==============================================
GridDB Python Client Library built using SWIG
==============================================

GridDB (https://github.com/griddb/griddb) is Database for IoT with both NoSQL interface and SQL Interface.
This is Python Client Library for GridDB.

Installation
=========================

1. Package dependencies
-------------------------

GridDB C Client
^^^^^^^^^^^^^^^^^^^^^^^^^

* **On Linux**

  Download and install RPM or DEB package in GridDB C Client (https://github.com/griddb/c_client/releases).

  Install RPM package by this command::

  $ sudo yum localinstall package_name.rpm

  Install DEB package by this command::

  $ sudo dpkg -i package_name.deb

* **On MacOS**

  Because GridDB Python Client already included C Client Library, so don't need install GridDB C Client on MacOS.

  GridDB C Client Libraries installed at *path/to/python/sites-package/*

  GridDB C Client licenses and header installed at *path/to/python/sites-package/griddb/griddb-c-client*

  Example::

  ~/.pyenv/versions/3.6.9/lib/python3.6/site-packages/griddb/

Pandas and Numpy
^^^^^^^^^^^^^^^^^^^^^^^^^

* Install Pandas and Numpy by these commands::

  $ python -m pip install numpy
  $ python -m pip install pandas

2. Install griddb_python
-------------------------

Install the griddb_python by this command::

$ python -m pip install griddb_python