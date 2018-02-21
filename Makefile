SWIG = swig -DSWIGWORDSIZE64
CXX = g++

ARCH = $(shell arch)

LDFLAGS = -Llibs -lpthread -lrt -lgridstore

CPPFLAGS = -fPIC -std=c++0x -g -O2
INCLUDES = -Iinclude -Isrc

INCLUDES_PYTHON = $(INCLUDES)	\
				-I/usr/include/python3.6

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
		  src/Row.cpp				\
		  src/QueryAnalysisEntry.cpp			\
		  src/RowKeyPredicate.cpp	\
		  src/RowSet.cpp			\
		  src/TimestampUtils.cpp			\

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
