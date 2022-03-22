SWIG = swig -DSWIGWORDSIZE64
CXX = g++

ARCH = $(shell arch)

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Linux)
    LDFLAGS = -Llibs -lpthread -lrt -lgridstore
endif
ifeq ($(UNAME_S), Darwin)
    LDFLAGS = -lpthread -lgridstore -undefined dynamic_lookup
endif

CPPFLAGS = -fPIC -std=c++0x -g -O2
INCLUDES = -Iinclude -Isrc
PY_CFLAGS  := $(shell python3-config --includes)
NUMPY_FLAGS := $(shell python3 -c "import site; print(site.getsitepackages()[0])")

INCLUDES_PYTHON = $(INCLUDES)	\
				${PY_CFLAGS}	\
				-I${NUMPY_FLAGS}/numpy/core/include

PROGRAM = _griddb_python.so
EXTRA = griddb_python.py griddb_python.pyc

SOURCES = 	  src/TimeSeriesProperties.cpp \
		  src/ContainerInfo.cpp			\
  		  src/AggregationResult.cpp	\
		  src/Container.cpp			\
		  src/Store.cpp			\
		  src/StoreFactory.cpp	\
		  src/PartitionController.cpp	\
		  src/Query.cpp				\
		  src/QueryAnalysisEntry.cpp			\
		  src/RowKeyPredicate.cpp	\
		  src/RowList.cpp	\
		  src/RowSet.cpp			\
		  src/TimestampUtils.cpp			\
		  src/Field.cpp \
		  src/Util.cpp

all: $(PROGRAM)

SWIG_DEF = src/griddb.i

SWIG_PYTHON_SOURCES = src/griddb_python.cxx

OBJS = $(SOURCES:.cpp=.o)
SWIG_PYTHON_OBJS = $(SWIG_PYTHON_SOURCES:.cxx=.o)

$(SWIG_PYTHON_SOURCES) : $(SWIG_DEF)
	$(SWIG) -outdir . -o $@ -c++ -python $<

.cpp.o:
	$(CXX) $(CPPFLAGS) -c -o $@ $(INCLUDES) $<

$(SWIG_PYTHON_OBJS): $(SWIG_PYTHON_SOURCES)
	$(CXX) $(CPPFLAGS) -c -o $@ $(INCLUDES_PYTHON) $<

_griddb_python.so: $(OBJS) $(SWIG_PYTHON_OBJS)
	$(CXX) -shared  -o $@ $(OBJS) $(SWIG_PYTHON_OBJS) $(LDFLAGS)

clean:
	rm -rf $(OBJS) $(SWIG_PYTHON_OBJS)
	rm -rf $(SWIG_PYTHON_SOURCES)
	rm -rf $(PROGRAM) $(EXTRA)
