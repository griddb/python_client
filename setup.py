#!/usr/bin/env python

"""
setup.py file for GridDB python client
"""

from distutils.command.build import build
import os

try:
    from setuptools import setup, Extension
except ImportError:
    from distutils.core import setup, Extension

try:
    with open('README.rst') as f:
        readme = f.read()
except IOError:
    readme = ''

os.environ["CXX"] = "g++"
os.environ["CC"] = "g++"

SOURCES = [
    'src/AggregationResult.cpp',
    'src/Container.cpp',
    'src/ContainerInfo.cpp',
    'src/Field.cpp',
    'src/PartitionController.cpp',
    'src/Query.cpp',
    'src/QueryAnalysisEntry.cpp',
    'src/RowKeyPredicate.cpp',
    'src/RowList.cpp',
    'src/RowSet.cpp',
    'src/Store.cpp',
    'src/StoreFactory.cpp',
    'src/TimeSeriesProperties.cpp',
    'src/TimestampUtils.cpp',
    'src/griddb.i',
    'src/Util.cpp'
]

DEPENDENTS = [
    'src/AggregationResult.h',
    'src/ContainerInfo.h',
    'src/Container.h',
    'src/ExpirationInfo.h',
    'src/Field.h'
    'src/GSException.h',
    'src/PartitionController.h',
    'src/Query.h',
    'src/QueryAnalysisEntry.h',
    'src/RowKeyPredicate.h',
    'src/RowList.h',
    'src/RowSet.h',
    'src/Store.h',
    'src/StoreFactory.h',
    'src/TimeSeriesProperties.h',
    'src/TimestampUtils.h',
    'src/gstype_python.i',
    'src/gstype.i',
    'src/Util.h',
    'include/gridstore.h'
]

INCLUDES = [
    'include',
    'src',
    os.environ['HOME'] + '/.pyenv/versions/3.6.9/lib/python3.6/site-packages/numpy/core/include/'
]

COMPILE_ARGS = [
    '-std=c++0x'
]

LIBRARIES = [
    'rt',
    'gridstore'
]

SWIG_OPTS = [
    '-DSWIGWORDSIZE64',
    '-c++',
    '-outdir',
    '.',
    '-Isrc'
]


class CustomBuild(build):
    sub_commands = [
        ('build_ext', build.has_ext_modules),
        ('build_py', build.has_pure_modules),
        ('build_clib', build.has_c_libraries),
        ('build_scripts', build.has_scripts)
    ]


griddb_module = Extension('_griddb_python',
                          sources=SOURCES,
                          include_dirs=INCLUDES,
                          libraries=LIBRARIES,
                          extra_compile_args=COMPILE_ARGS,
                          swig_opts=SWIG_OPTS,
                          depends=DEPENDENTS
                          )

classifiers = [
    "License :: OSI Approved :: Apache Software License",
    "Operating System :: POSIX :: Linux",
    "Programming Language :: Python :: 3.6"
]

setup(name='griddb_python',
      version='0.8.3',
      author='Katsuhiko Nonomura',
      author_email='contact@griddb.org',
      description='GridDB Python Client Library built using SWIG',
      long_description=readme,
      ext_modules=[griddb_module],
      py_modules=['griddb_python'],
      url='https://github.com/griddb/python_client/',
      license='Apache Software License',
      cmdclass={'build': CustomBuild},
      long_description_content_type = 'text/x-rst',
      classifiers=classifiers
      )
