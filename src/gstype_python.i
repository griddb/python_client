/*
   Copyright (c) 2017 TOSHIBA Digital Solutions Corporation.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

%{
#include <ctime>
#include <datetime.h>

%}
%ignore griddb::Row;
%ignore griddb::Container::getGSContainerInfo;
%ignore griddb::RowSet::next_row;
%ignore griddb::RowSet::get_next_query_analysis;
%ignore griddb::RowSet::get_next_aggregation;

%pythonbegin %{
from enum import IntEnum
%}

%pythoncode {
class ContainerType(IntEnum):
    COLLECTION = 0
    TIME_SERIES = 1
    def __int__(self):
        return self._value
class IndexType(IntEnum):
    def __int__(self):
        return int(self.value)
    DEFAULT = 0
    TREE = 1
    HASH = 2
    SPATIAL = 3
class RowSetType(IntEnum):
    def __int__(self):
        return int(self.value)
    CONTAINER_ROWS = 0
    AGGREGATION_RESULT = 1
    QUERY_ANALYSIS = 2
class FetchOption(IntEnum):
    def __int__(self):
        return int(self.value)
    LIMIT = 0
class TimeUnit(IntEnum):
    def __int__(self):
        return int(self.value)
    YEAR = 0
    MONTH = 1
    DAY = 2
    HOUR = 3
    MINUTE = 4
    SECOND = 5
    MILLISECOND = 6
class Type(IntEnum):
    STRING = 0
    BOOL = 1
    BYTE = 2
    SHORT = 3
    INTEGER = 4
    LONG = 5
    FLOAT = 6
    DOUBLE = 7
    TIMESTAMP = 8
    GEOMETRY = 9
    BLOB = 10
    STRING_ARRAY = 11
    BOOL_ARRAY = 12
    BYTE_ARRAY = 13
    SHORT_ARRAY = 14
    INTEGER_ARRAY = 15
    LONG_ARRAY = 16
    FLOAT_ARRAY = 17
    DOUBLE_ARRAY = 18
    TIMESTAMP_ARRAY = 19
    def __int__(self):
        return self._value
class TypeOption(IntEnum):
    def __int__(self):
        return int(self.value)
    NULLABLE = 0
    NOT_NULL = 1
}

%include <attribute.i>

/**
 * Support find sub-string from string.
 * Use for create UTC datetime object in Python
 */
%fragment("substring", "header") {
GSChar* substring(GSChar* str, size_t begin, size_t len) {
    if ( strlen(str) == 0 || strlen(str) < begin || strlen(str) < (begin+len))
        return NULL;
    return strndup(str + begin, len);
} 
}

/**
 * Support convert const GSChar* to PyObject* for typemap out
 */
%fragment("convertStrToObj", "header") {
PyObject* convertStrToObj(const GSChar* str) {
    %#if PY_MAJOR_VERSION < 3
        return PyString_FromString(str);
    %#else
        return PyUnicode_FromString(str);
    %#endif
} 
}

%fragment("convertObjToStr", "header") {
char* convertObjToStr(PyObject *string) {
    %#if PY_MAJOR_VERSION < 3
        return PyString_AsString(string);
    %#else
        return PyUnicode_AsUTF8(string);
    %#endif
} 
}

/**
 * Support check PyObject* is string
 */
%fragment("checkPyObjIsStr", "header") {
bool checkPyObjIsStr(PyObject* obj) {
    %#if PY_MAJOR_VERSION < 3
        return PyString_Check(obj);
    %#else
        return PyUnicode_Check(obj);
    %#endif
} 
}

/*
* fragment to support converting data for GSRow
*/
%fragment("convertFieldToObject", "header", fragment="substring", 
        fragment="convertStrToObj") {
static PyObject* convertFieldToObject(Field &field) {
    switch (field.type) {
        case GS_TYPE_BLOB: {
            PyObject *o = PyByteArray_FromStringAndSize((GSChar *)field.value.asBlob.data, field.value.asBlob.size);
            return o;
        }
        case GS_TYPE_BOOL:
            return PyBool_FromLong(field.value.asBool);
        case GS_TYPE_INTEGER:
            return PyInt_FromLong(field.value.asInteger);
        case GS_TYPE_LONG:
            return PyLong_FromLong(field.value.asLong);
        case GS_TYPE_FLOAT:
            return PyFloat_FromDouble(field.value.asFloat);
        case GS_TYPE_DOUBLE:
            return PyFloat_FromDouble(field.value.asDouble);
        case GS_TYPE_STRING:
            return convertStrToObj(field.value.asString);

        case GS_TYPE_TIMESTAMP: {
            // In C-API there is function PyDateTime_FromTimestamp convert from datetime to local datetime (not UTC).
            // But GridDB use UTC datetime => use the string output from gsFormatTime to convert to UTC datetime

            if (!PyDateTimeAPI) {
                PyDateTime_IMPORT; 
            }
            PyObject *dateTime = NULL;
            size_t bufSize = 100;
            GSChar strBuf[bufSize];
            gsFormatTime (field.value.asTimestamp, strBuf, bufSize);

            //Date format is YYYY-MM-DDTHH:mm:ss.sssZ
            char* substr = substring(strBuf, 0, 4);
            int year = atoi(substr);
            free(substr);
            substr = substring(strBuf, 6, 2);
            int month = atoi(substr);
            free(substr);
            substr = substring(strBuf, 8, 2);
            int day = atoi(substr);
            free(substr);
            substr = substring(strBuf, 11, 2);
            int hour = atoi(substr);
            free(substr);
            substr = substring(strBuf, 14, 2);
            int minute = atoi(substr);
            free(substr);
            substr = substring(strBuf, 17, 2);
            int second = atoi(substr);
            free(substr);
            substr = substring(strBuf, 20, 3);
            int usecond = atoi(substr)*1000;
            free(substr);

            dateTime = PyDateTime_FromDateAndTime(year, month, day, hour, minute, second, usecond);
            return dateTime;
        }
%#if GS_COMPATIBILITY_SUPPORT_3_5
        case GS_TYPE_NULL:
            return Py_None;
%#endif
        case GS_TYPE_BYTE:
            return PyInt_FromLong(field.value.asByte);
        case GS_TYPE_SHORT:
            return PyInt_FromLong(field.value.asShort);
        default:
            return NULL;
    }

    return NULL;
} 
}

%fragment("convertObjectToField", "header", fragment = "SWIG_AsCharPtrAndSize",
        fragment = "checkPyObjIsStr", fragment="convertObjToStr") {
    static bool convertObjectToField(Field &field, PyObject* value) {
        size_t size = 0;
        int res;
        char* v = 0;
        bool vbool;
        int *alloc = (int*) malloc(sizeof(int));
        if(alloc == NULL) {
            return false;
        }
        memset(alloc, 0, sizeof(int));
        if (!PyDateTimeAPI) {
            PyDateTime_IMPORT; 
        }

        if (PyBool_Check(value)) {
            vbool = (PyInt_AsLong(value))? true : false;
            field.value.asBool = vbool;
            field.type = GS_TYPE_BOOL;
        } else if (PyDateTime_Check(value)) {
            int year = PyDateTime_GET_YEAR(value);
            int month = PyDateTime_GET_MONTH(value);
            int day = PyDateTime_GET_DAY(value);
            int hour = PyDateTime_DATE_GET_HOUR(value);
            int minute = PyDateTime_DATE_GET_MINUTE(value);
            int second = PyDateTime_DATE_GET_SECOND(value);
            int milliSecond = PyDateTime_DATE_GET_MICROSECOND(value)/1000;
            char s[30];
            sprintf(s, "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",year,month,day,hour,minute,second,milliSecond);
            GSBool retB = gsParseTime(s, &field.value.asTimestamp);
            if (retB == GS_FALSE) {
                return false;
            }
            field.type = GS_TYPE_TIMESTAMP;
        } else if (PyInt_Check(value)) {
            field.value.asLong = PyLong_AsLong(value);
            field.type = GS_TYPE_LONG;
        } else if (PyLong_Check(value)) {
            field.value.asLong = PyLong_AsLong(value);
            field.type = GS_TYPE_LONG;
        } else if (checkPyObjIsStr(value)) {
            res = SWIG_AsCharPtrAndSize(value, &v, &size, alloc);
            if (!SWIG_IsOK(res)) {
                return false;
            }
            field.value.asString = v; 
            field.type = GS_TYPE_STRING;
        } else if (PyFloat_Check(value)) {
            field.value.asFloat = PyFloat_AsDouble(value);
            field.type = GS_TYPE_FLOAT;
        } else if(PyByteArray_Check(value)) {
            field.value.asBlob.size = PyByteArray_Size(value);
            if (field.value.asBlob.size > 0) {
                void *mydata = malloc(sizeof(GSChar) * field.value.asBlob.size);
                memset(mydata, 0x0, sizeof(GSChar) * field.value.asBlob.size);
                if(mydata == NULL) {
                    return false;
                }
                memcpy(mydata, PyByteArray_AsString(value), field.value.asBlob.size);
                field.value.asBlob.data = mydata;
            }
            field.type = GS_TYPE_BLOB;
        } else if(value == Py_None) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
            field.type = GS_TYPE_NULL;
%#else
            return false;
%#endif
        }else {
            return false;
        }
        return true;
    }
}

/**
 * Support covert Field from PyObject* to C Object with specific type
 */
%fragment("convertObjectToFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize", 
        fragment = "checkPyObjIsStr", fragment = "convertObjToStr") {
    static bool convertObjectToFieldWithType(Field &field, PyObject* value, GSType type) {
        size_t size = 0;
        int res;
        char* v = 0;
        bool vbool;

        int xxx = 0;
        int *alloc = &xxx;
        
        field.type = type;

        if (value == Py_None) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
            field.type = GS_TYPE_NULL;
            return true;
%#else
            return false;
%#endif
        }

        GSChar *mydata;
        void *blobData;
        int year, month, day, hour, minute, second, milliSecond;
        char s[30];
        int checkConvert = 0;
        GSBool retConvertTimestamp;
        char* pyobjToStr;
        char* buffer;
        switch(type) {
            case (GS_TYPE_STRING):
                if (!checkPyObjIsStr(value)) {
                    return false;
                }
                res = SWIG_AsCharPtrAndSize(value, &v, &size, alloc);
                if (!SWIG_IsOK(res)) {
                   return false;
                }
                field.value.asString = v;
                field.type = GS_TYPE_STRING;
                break;

            case (GS_TYPE_BOOL):
                checkConvert = SWIG_AsVal_bool(value, (bool*) &field.value.asBool);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                break;

            case (GS_TYPE_BYTE):
                if (!(PyInt_Check(value) || PyLong_Check(value))) {
                    return false;
                }
                field.value.asByte = PyLong_AsLong(value);
                break;

            case (GS_TYPE_SHORT):

                if (!(PyInt_Check(value) || PyLong_Check(value))) {
                    return false;
                }
                field.value.asShort = PyLong_AsLong(value);
                break;

            case (GS_TYPE_INTEGER):
                checkConvert = SWIG_AsVal_int(value, &field.value.asInteger);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
            break;

            case (GS_TYPE_LONG):
                checkConvert = SWIG_AsVal_long(value, &field.value.asLong);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                break;

            case (GS_TYPE_FLOAT):
                if (!PyFloat_Check(value)) {
                    return false;
                }
                field.value.asFloat = PyFloat_AsDouble(value);
                break;

            case (GS_TYPE_DOUBLE):
                checkConvert = SWIG_AsVal_double(value, &field.value.asDouble);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                break;

            case (GS_TYPE_TIMESTAMP):
                if (!PyDateTimeAPI) {
                    PyDateTime_IMPORT; 
                }
                if (PyDateTime_Check(value)) {
                    year = PyDateTime_GET_YEAR(value);
                    month = PyDateTime_GET_MONTH(value);
                    day = PyDateTime_GET_DAY(value);
                    hour = PyDateTime_DATE_GET_HOUR(value);
                    minute = PyDateTime_DATE_GET_MINUTE(value);
                    second = PyDateTime_DATE_GET_SECOND(value);
                    milliSecond = PyDateTime_DATE_GET_MICROSECOND(value)/1000;
                    sprintf(s, "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", year, month, day, hour, minute, second, milliSecond);
                    retConvertTimestamp = gsParseTime(s, &field.value.asTimestamp);
                    if (retConvertTimestamp == GS_FALSE) {
                        return false;
                    }
                } else if (PyFloat_Check(value)) {
                    double dVal;
                    checkConvert = SWIG_AsVal_double(value, &dVal);
                    if (!SWIG_IsOK(checkConvert)) {
                        return false;
                    }
                    field.value.asTimestamp = ((int64_t)(dVal * 1000));
                } else if (PyInt_Check(value)) {
                    checkConvert = SWIG_AsVal_long(value, &field.value.asTimestamp);
                    if (!SWIG_IsOK(checkConvert)) {
                        return false;
                    }
                } else {
                    return false;
                }
                break;
            case (GS_TYPE_BLOB):
                if(!PyByteArray_Check(value)) {
                    return false;
                }
                field.value.asBlob.size = PyByteArray_Size(value);
                if (field.value.asBlob.size > 0) {
                blobData = malloc(sizeof(GSChar) * field.value.asBlob.size);
                memset(blobData, 0x0, sizeof(GSChar) * field.value.asBlob.size);
                if(blobData == NULL) {
                    return false;
                }
                memcpy(blobData, PyByteArray_AsString(value), field.value.asBlob.size);
                field.value.asBlob.data = blobData;
                }
                break;
            case (GS_TYPE_GEOMETRY):
            case (GS_TYPE_STRING_ARRAY):
            case (GS_TYPE_BOOL_ARRAY):
            case (GS_TYPE_BYTE_ARRAY):
            case (GS_TYPE_SHORT_ARRAY):
            case (GS_TYPE_INTEGER_ARRAY):
            case (GS_TYPE_LONG_ARRAY):
            case (GS_TYPE_FLOAT_ARRAY):
            case (GS_TYPE_DOUBLE_ARRAY):
            case (GS_TYPE_TIMESTAMP_ARRAY):
            default:
                //Not support for now
                return false;
                break;
        }
        return true;
    }
}

/**
* Typemaps for put_container() function
*/
%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (const GSColumnInfo* props, int propsCount)
(PyObject* list, int i, size_t size = 0, int* alloc = 0, int res, char* v = 0, int val) {
//Convert Python list of tuple into GSColumnInfo properties
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        $2 = 0;
        $1 = NULL;
        return NULL;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        $1 = (GSColumnInfo *) malloc($2*sizeof(GSColumnInfo));
        alloc = (int*) malloc($2*sizeof(int));

        if($1 == NULL || alloc == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        memset($1, 0x0, $2*sizeof(GSColumnInfo));
        memset(alloc, 0x0, $2*sizeof(int));

        i = 0;
        while (i < $2) {
            list = PyList_GetItem($input, i);
            if (!PyList_Check(list)) {
                PyErr_SetString(PyExc_ValueError, "Expected a List as List element");
                SWIG_fail;
            }
            res = SWIG_AsCharPtrAndSize(PyList_GetItem(list, 0), &v, &size, &alloc[i]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "name");
            }

            if(!PyInt_Check(PyList_GetItem(list, 1))) {
                PyErr_SetString(PyExc_ValueError, "Expected an Integer as column type");
                SWIG_fail;
            }

            $1[i].name = v;
            $1[i].type = (int) PyInt_AsLong(PyList_GetItem(list, 1));
%#if GS_COMPATIBILITY_SUPPORT_3_5
            int tupleLength = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(list)));
            //Case user input option parameter
            if (tupleLength == 3) {
                if(!PyInt_Check(PyList_GetItem(list, 2))) {
                    PyErr_SetString(PyExc_ValueError, "Expected an Integer as column option");
                    SWIG_fail;
                }
                $1[i].options = (int) PyInt_AsLong(PyList_GetItem(list, 2));
            }
%#endif
            i++;
        }
    }
}

%typemap(typecheck) (const GSColumnInfo* props, int propsCount) {
    $1 = PyList_Check($input) ? 1 : 0;
}

%typemap(freearg) (const GSColumnInfo* props, int propsCount) (int i) {
    if ($1) {
        for (i = 0; i < $2; i++) {
            if (alloc$argnum[i] == SWIG_NEWOBJ) {
                %delete_array($1[i].name);
            }
        }
        free((void *) $1);
    }

    if (alloc$argnum) {
        free(alloc$argnum);
    }
}

/**
* Typemaps for get_store() function
*/
%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (const GSPropertyEntry* props, int propsCount)
(int i, int j, Py_ssize_t si, PyObject* key, PyObject* val, size_t size = 0, int* alloc = 0, int res, char* v = 0) {
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        return NULL;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        $1 = (GSPropertyEntry *) malloc($2*sizeof(GSPropertyEntry));
        alloc = (int*) malloc($2 * 2 * sizeof(int));
        if($1 == NULL || alloc == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }

        memset(alloc, 0, $2 * 2 * sizeof(int));
        i = 0;
        j = 0;
        si = 0;
        while (PyDict_Next($input, &si, &key, &val)) {
            res = SWIG_AsCharPtrAndSize(key, &v, &size, &alloc[j]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "name");
            }

            $1[i].name = v;
            res = SWIG_AsCharPtrAndSize(val, &v, &size, &alloc[j + 1]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "value");
            }
            $1[i].value = v;
            i++;
            j+=2;
        }
    }
}

%typemap(freearg) (const GSPropertyEntry* props, int propsCount) (int i = 0, int j = 0) {
    if ($1) {
        for (i = 0; i < $2; i++) {
            if (alloc$argnum[j] == SWIG_NEWOBJ) {
                %delete_array($1[i].name);
            }
            if (alloc$argnum[j + 1] == SWIG_NEWOBJ) {
                %delete_array($1[i].value);
            }
            j += 2;
        }
        free((void *) $1);
    }

    if (alloc$argnum) {
        free(alloc$argnum);
    }
}

/**
* Typemaps for fetch_all() function
*/
%typemap(in) (GSQuery* const* queryList, size_t queryCount) (PyObject* pyQuery, std::shared_ptr<griddb::Query> query, void *vquery, int i, int res = 0) {
    if(!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        return NULL;
    }
    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    i = 0;
    if($2 > 0) {
        $1 = (GSQuery**) malloc($2*sizeof(GSQuery*));
        if($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        while (i < $2) {
            pyQuery = PyList_GetItem($input,i);
            {
                int newmem = 0;
                res = SWIG_ConvertPtrAndOwn(pyQuery, (void **) &vquery, $descriptor(std::shared_ptr<griddb::Query>*), %convertptr_flags, &newmem);
                if (!SWIG_IsOK(res)) {
                    %argument_fail(res, "$type", $symname, $argnum);
                }
                if (vquery) {
                    query = *%reinterpret_cast(vquery, std::shared_ptr<griddb::Query>*);
                    $1[i] = query->gs_ptr();
                    if (newmem & SWIG_CAST_NEW_MEMORY) {
                        delete %reinterpret_cast(vquery, std::shared_ptr<griddb::Query>*);
                    }
                }
            }

            i++;
        }
    }
}

%typemap(freearg) (GSQuery* const* queryList, size_t queryCount) {
    if ($1) {
        free((void *) $1);
    }
}

/**
* Typemaps for set_field_by_byte_array() function
*/
%typemap(in) (const int8_t *fieldValue, size_t size) (int i) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        $1 = (int8_t *) malloc($2*sizeof(int8_t));
        if($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        i = 0;
        while(i < $2) {
            $1[i] = (int8_t)PyInt_AsLong(PyList_GetItem($input,i));
            i++;
        }
    }
}

%typemap(freearg) (const int8_t *fieldValue, size_t size) {
    if ($1) {
        free((void *) $1);
    }
}

/**
* Typemaps input for get_multi_container_row() function
*/

%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount) (PyObject* key, PyObject* val, std::shared_ptr<griddb::RowKeyPredicate> pPredicate, GSRowKeyPredicateEntry* pList, void *vpredicate, Py_ssize_t si, int i, int res = 0, size_t size = 0, int* alloc = 0, char* v = 0) {
    if(!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    $1 = NULL;
    i = 0;
    si = 0;
    if($2 > 0) {
        pList = (GSRowKeyPredicateEntry*) malloc($2*sizeof(GSRowKeyPredicateEntry));
        alloc = (int*) malloc($2 * sizeof(int));

        if(pList == NULL || alloc == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        memset(alloc, 0x0, $2*sizeof(int));
        $1 = &pList;

        while (PyDict_Next($input, &si, &key, &val)) {
            GSRowKeyPredicateEntry *predicateEntry = &pList[i];
            res = SWIG_AsCharPtrAndSize(key, &v, &size, &alloc[i]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "containerName");
            }
            predicateEntry->containerName = v;
            //Get GSRowKeyPredicate pointer from RowKeyPredicate pyObject
            int newmem = 0;
            res = SWIG_ConvertPtrAndOwn(val, (void **) &vpredicate, $descriptor(std::shared_ptr<griddb::RowKeyPredicate>*), %convertptr_flags, &newmem);
            if (!SWIG_IsOK(res)) {
                %argument_fail(res, "$type", $symname, $argnum);
            }
            if (vpredicate) {
                pPredicate = *%reinterpret_cast(vpredicate, std::shared_ptr<griddb::RowKeyPredicate>*);
                predicateEntry->predicate = pPredicate->gs_ptr();
                if (newmem & SWIG_CAST_NEW_MEMORY) {
                    delete %reinterpret_cast(vpredicate, std::shared_ptr<griddb::RowKeyPredicate>*);
                }
            }
            i++;
        }
    }
}

%typemap(freearg) (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount) (int i, GSRowKeyPredicateEntry* pList) {
    if ($1 && *$1) {
        pList = *$1;
        for (i = 0; i < $2; i++) {
            if (alloc$argnum[i] == SWIG_NEWOBJ) {
                %delete_array(pList[i].containerName);
            }
        }
        free((void *) pList);
    }

    if (alloc$argnum) {
        free(alloc$argnum);
    }
}

/**
* Typemaps output for partition controller function
*/
%typemap(in, numinputs=0) (const GSChar *const ** stringList, size_t *size) (GSChar **nameList1, size_t size1) {
    $1 = &nameList1;
    $2 = &size1;
}

%typemap(argout, numinputs=0, fragment="convertStrToObj") (const GSChar *const ** stringList, size_t *size) (  int i, size_t size) {
    GSChar** nameList1 = *$1;
    size_t size = *$2;
    $result = PyList_New(size);
    for (i = 0; i < size; i++) {
        PyObject *o = convertStrToObj(nameList1[i]);
        PyList_SetItem($result,i,o);
    }
}

%typemap(in, numinputs=0) (const int **intList, size_t *size) (int *intList1, size_t size1) {
    $1 = &intList1;
    $2 = &size1;
}

%typemap(argout,numinputs=0) (const int **intList, size_t *size) (int i, size_t size) {
    int* intList = *$1;
    size_t size = *$2;
    $result = PyList_New(size);
    for (i = 0; i < size; i++) {
        PyObject *o = PyInt_FromLong(intList[i]);
        PyList_SetItem($result,i,o);
    }
}

%typemap(in, numinputs=0) (const long **longList, size_t *size) (long *longList1, size_t size1) {
    $1 = &longList1;
    $2 = &size1;
}

%typemap(argout,numinputs=0) (const long **longList, size_t *size) (int i, size_t size) {
    long* longList = *$1;
    size_t size = *$2;
    $result = PyList_New(size);
    for (i = 0; i < size; i++) {
        PyObject *o = PyFloat_FromDouble(longList[i]);
        PyList_SetItem($result,i,o);
    }
}

%typemap(in) (const GSBlob *fieldValue) {
    if(!PyByteArray_Check($input)){
        PyErr_SetString(PyExc_ValueError, "Expected a byte array");
        SWIG_fail;
    }

    $1 = (GSBlob*) malloc(sizeof(GSBlob));
    if($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }

    $1->size = PyByteArray_Size($input);
    $1->data = PyByteArray_AsString($input);
}

%typemap(freearg) (const GSBlob *fieldValue) {
    if ($1) {
        free((void *) $1);
    }
}

%typemap(in, numinputs = 0) (GSBlob *value) (GSBlob pValue) {
    $1 = &pValue;
}

%typemap(argout) (GSBlob *value) {
    GSBlob output = *$1;
    $result = PyByteArray_FromStringAndSize((char*) output.data, output.size);
}

%typemap(out, fragment="convertStrToObj") GSColumnInfo {
    $result = PyTuple_New(2);
    PyTuple_SetItem($result, 0, convertStrToObj($1.name));
    PyTuple_SetItem($result, 1, PyInt_FromLong($1.type));
}

/*
* typemap for get function in AggregationResult class
*/
%typemap(in, numinputs = 0) (Field *agValue) (Field tmpAgValue){
    $1 = &tmpAgValue;
}
%typemap(argout, fragment = "convertFieldToObject") (Field *agValue) {
    $result = convertFieldToObject(*$1);
}

/**
* Typemaps for put_row() function
*/
%typemap(in, fragment="convertObjectToField") (griddb::Row *row) {
    if(!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    griddb::Row * row = new griddb::Row(leng);
    Field *tmpField = row->get_field_ptr();
    int i;

    for(i = 0; i < leng; i++) {
        if(!(convertObjectToField(tmpField[i], PyList_GetItem($input, i)))) {
            %variable_fail(1, "String", "can not create row based on input");
        }
    }

    $1 = row;
}

%typemap(freearg) (griddb::Row *row) {
    if($1) {
        delete $1;
    }
}

/**
* Typemaps for put_row() function
*/
%typemap(in, fragment="convertObjectToFieldWithType") (griddb::Row *rowContainer) {
    if(!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    griddb::Row * row = new griddb::Row(leng);
    Field *tmpField = row->get_field_ptr();
    int i;


    if (leng != arg1->getColumnCount()) {
        %variable_fail(1, "Row", "num row is different with container info");
    }
    GSType* typeList = arg1->getGSTypeList();
    for(i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if(!(convertObjectToFieldWithType(tmpField[i], PyList_GetItem($input, i), type))) {
            char gsType[200];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }

    $1 = row;
}

%typemap(freearg) (griddb::Row *rowContainer) {
    if($1) {
        delete $1;
    }
}

/*
* typemap for get_row
*/

%typemap(in, fragment = "convertObjectToFieldWithType") (Field* keyFields)(Field field) {
    if ($input == Py_None) {
        $1 = NULL;
    } else {
        $1 = &field;
        GSType type = arg1->getGSTypeList()[0];
        if(!convertObjectToFieldWithType(*$1, $input, type)) {
             %variable_fail(1, "String", "can not convert to row filed");
        }
    }
}

%typemap(freearg) (Field* keyFields) {
    if($1) {
        if ($1->value.asString && $1->type == GS_TYPE_STRING) {
            %delete_array($1->value.asString);
        }
        if ($1->value.asBlob.data && $1->type == GS_TYPE_BLOB) {
            free((void*)$1->value.asBlob.data);
        }
    }
}

%typemap(in, numinputs = 0) (griddb::Row *rowdata) {
    $1 = new griddb::Row();
}

%typemap(freearg) (griddb::Row *rowdata) {
    if ($1) {
        delete $1;
    }
}

%typemap(argout, fragment = "convertFieldToObject") (griddb::Row *rowdata) {
    PyObject *outList = PyList_New($1->get_count());
    if(outList == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    int i;
    for(int i = 0; i < $1->get_count(); i++) {
        PyList_SetItem(outList, i, convertFieldToObject($1->get_field_ptr()[i]));
    }
    $result = outList;
}

/**
 * Create typemap for RowKeyPredicate.set_range
 */
%typemap(in, fragment= "convertObjectToField") (Field* startKey ) {
    Field* startKey1 = (Field*) malloc(sizeof(Field));

    if(!(convertObjectToField(*startKey1, $input))) {
        %variable_fail(1, "String", "can not create row based on input");
    }
    $1 = startKey1;
}

%typemap(freearg) (Field* startKey) {
    if($1) {
        if ($1->value.asString) {
            %delete_array($1->value.asString);
        }
        if ($1->value.asBlob.data) {
            free((void*)$1->value.asBlob.data);
        }
        free((void*)$1);
    }
}

%typemap(in, fragment= "convertObjectToField") (Field* finishKey ) {
    Field* finishKey1 = (Field *) malloc(sizeof(Field));

    if(!(convertObjectToField(*finishKey1, $input))) {
        %variable_fail(1, "String", "can not create row based on input");
    }
    $1 = finishKey1;
}

%typemap(freearg) (Field* finishKey) {
    if($1) {
        if ($1->value.asString) {
            %delete_array($1->value.asString);
        }
        if ($1->value.asBlob.data) {
            free((void*)$1->value.asBlob.data);
        }
        free((void*)$1);
    }
}

/**
 * Typemap for RowKeyPredicate.get_range
 */
%typemap(in, numinputs = 0) (Field* startField, Field* finishField) (Field startKeyTmp, Field finishKeyTmp) {
    $1 = &startKeyTmp;
    $2 = &finishKeyTmp;
}

%typemap(argout, fragment="convertFieldToObject") (Field* startField, Field* finishField) {
    int length = 2;
    $result = PyList_New(2);
    if($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    PyList_SetItem($result,0,convertFieldToObject(*$1));
    PyList_SetItem($result,1,convertFieldToObject(*$2));
}

/**
 * Typemap for RowKeyPredicate.set_distinct_keys
 */
%typemap(in, fragment="convertObjectToField") (const Field *keys, size_t keyCount) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        return NULL;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        $1 = (Field *) malloc($2*sizeof(Field));
        for (int i = 0; i< $2; i++) {
            if(!(convertObjectToField($1[i], PyList_GetItem($input, i)))) {
                %variable_fail(1, "String", "can not create row based on input");
            }
        }
    }
}

%typemap(freearg) (const Field *keys, size_t keyCount) {
    if($1) {
        if ($2 > 0) {
            for (int i = 0; i< $2; i++) {
                Field* key = &$1[i];
                if (key->value.asString) {
                    %delete_array(key->value.asString);
                }
                if (key->value.asBlob.data) {
                    free((void*)key->value.asBlob.data);
                }
            }
        }

        free((void*)$1);
    }
}

/**
* Typemaps output for RowKeyPredicate.get_distinct_keys
*/
%typemap(in, numinputs=0) (Field **keys, size_t* keyCount) (Field *keys1, size_t keyCount1) {
    $1 = &keys1;
    $2 = &keyCount1;
}

%typemap(argout,numinputs=0, fragment="convertFieldToObject") (Field **keys, size_t* keyCount) (  int i, size_t size) {
    size_t size = *$2;
    $result = PyList_New(size);
    if($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    Field* keyList = *($1);
    int num;
    for (num = 0; num < size; num++) {

        PyObject *o = convertFieldToObject(keyList[num]);
        PyList_SetItem($result,num,o);
    }
}

%typemap(freearg) (Field **keys, size_t* keyCount) {
    if($1) {
        if ($2 > 0) {
            for (int i = 0; i< *$2; i++) {
                Field* key = $1[i];
                if (key->value.asString) {
                    %delete_array(key->value.asString);
                }
                if (key->value.asBlob.data) {
                    free((void*)key->value.asBlob.data);
                }
            }
        }
        free((void*)* $1);
    }
}

/**
 * Typemaps for Store.multi_put
 */
%typemap(in, fragment="convertObjectToFieldWithType", fragment="convertObjToStr") (griddb::Row*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) () {
    if(!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $1 = NULL;
    $2 = NULL;
    $3 = NULL;
    $4 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    if($4 > 0) {
        $1 = (griddb::Row***)malloc($4 * sizeof(griddb::Row**));
        $2 = (int*)malloc($4 * sizeof(int));
        $3 = (char **)malloc($4 * sizeof(char*));
        int i = 0;
        int j = 0;
        Py_ssize_t si = 0;
        PyObject* containerName;
        PyObject* listRowContainer;
        griddb::ContainerInfo* containerInfoTmp;
        ColumnInfoList infoListTmp;
        while (PyDict_Next($input, &si, &containerName, &listRowContainer)) {
            int numRowOfContainer = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(listRowContainer)));
            $1[i] = (griddb::Row**)malloc(numRowOfContainer * sizeof(griddb::Row*));
            $2[i] = numRowOfContainer;
            $3[i] = convertObjToStr(containerName);
            j = 0;
            int length;
            containerInfoTmp = arg1->get_container_info($3[i]);
            infoListTmp = containerInfoTmp->get_column_info_list();
            int* typeArr = (int*) malloc(infoListTmp.size * sizeof(int));
            for (int m = 0; m < infoListTmp.size; m++) {
                typeArr[m] = infoListTmp.columnInfo[m].type;
            }
            while(j < numRowOfContainer) {
                PyObject* rowTmp = PyList_GetItem(listRowContainer, j);
                if (!PyList_Check(rowTmp)) {
                    PyErr_SetString(PyExc_ValueError, "Expected a List");
                    free((void *)typeArr);
                    $2[i] = j;
                    $4 = i + 1;
                    SWIG_fail;
                }
                length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
                $1[i][j] = new griddb::Row(length);
                Field *tmpField = $1[i][j]->get_field_ptr();
                int k;
                for(k = 0; k < length; k++) {
                    if(!(convertObjectToFieldWithType(tmpField[k], PyList_GetItem(rowTmp, k), typeArr[k]))) {
                        char gsType[200];
                        sprintf(gsType, "Invalid value for column %d, type should be : %d", k, typeArr[k]);
                        PyErr_SetString(PyExc_ValueError, gsType);
                        // Mark the element to delete.
                        $2[i] = j+1;
                        $4 = i + 1;
                        free((void *)typeArr);
                        SWIG_fail;
                    }
                }
                j++;
            }
            free((void *)typeArr);
            i++;
        }

    }
}

%typemap(freearg) (griddb::Row*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) {
    if($4) {
        for(int i = 0; i < $4; i++) {
            for (int j = 0; j < $2[i]; j++ ) {
                if ($1[i][j]) {
                    delete($1[i][j]);
                }
            }
            free((void*)$1[i]);
        }
        free((void*)$1);
        free((void*)$2);
        free((void*)$3);
    }
}

/**
 * Typemaps output for Store.multi_get() function
 */
%typemap(in, numinputs = 0) (std::vector<griddb::Row*> *listRow, size_t **listRowContainerCount,
        char*** listContainerName, size_t* containerCount) (std::vector<griddb::Row*> listRow1, size_t *listRowContainerCount1,
        char** listContainerName1, size_t containerCount1) {
    $1 = &listRow1;
    $2 = &listRowContainerCount1;
    $3 = &listContainerName1;
    $4 = &containerCount1;
}

%typemap(argout, numinputs = 0, fragment="convertStrToObj") (std::vector<griddb::Row*> *listRow, size_t **listRowContainerCount,
        char*** listContainerName, size_t* containerCount) () {
    PyObject* dict = PyDict_New();
    int separateCount = 0;
    for(int i = 0; i < *$4; i++) {
        PyObject* key = convertStrToObj((*$3)[i]);
        PyObject* list = PyList_New((*$2)[i]);
        for(int j = 0; j < (*$2)[i]; j++) {
            griddb::Row* rowPtr = $1->at(separateCount);
            PyObject *outList = PyList_New(rowPtr->get_count());
            if(outList == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                SWIG_fail;
            }
            for(int k = 0; k < rowPtr->get_count(); k++) {
                PyList_SetItem(outList, k, convertFieldToObject(rowPtr->get_field_ptr()[k]));
            }
            PyList_SetItem(list, j, outList);
            separateCount += 1;
        }
        
        //Add entry to map
        PyDict_SetItem(dict, key, list);
    }

    $result = dict;
}

%typemap(freearg) (std::vector<griddb::Row*> *listRow, size_t **listRowContainerCount,
        char*** listContainerName, size_t* containerCount) {
    int separateCount = 0;
    if(*$4) {
        for(int i = 0; i < *$4; i++) {
            for(int j = 0; j < (*$2)[i]; j++) {
                griddb::Row* rowPtr = $1->at(separateCount);
                delete(rowPtr);
                separateCount += 1;
            }
            free((void*)(*$3)[i]);
        }
        $1->clear();
        free((void*)*$2);
        free((void*)*$3);
    }
}

/**
 * Typemap for QueryAnalysisEntry.get()
 */
%typemap(in, numinputs = 0) (GSQueryAnalysisEntry* queryAnalysis) (GSQueryAnalysisEntry queryAnalysis1) {
    $1 = (GSQueryAnalysisEntry*) malloc(sizeof(GSQueryAnalysisEntry));
}

%typemap(argout, fragment="convertStrToObj") (GSQueryAnalysisEntry* queryAnalysis) () {
    const int size = 6;
    $result = PyList_New(size);
    PyList_SetItem($result, 0, PyInt_FromLong($1->id));
    PyList_SetItem($result, 1, PyInt_FromLong($1->depth));
    PyList_SetItem($result, 2, convertStrToObj($1->type));
    PyList_SetItem($result, 3, convertStrToObj($1->valueType));
    PyList_SetItem($result, 4, convertStrToObj($1->value));
    PyList_SetItem($result, 5, convertStrToObj($1->statement));
}

%typemap(freearg) (GSQueryAnalysisEntry* queryAnalysis) {
    if($1) {
        free((void*)$1);
    }
}

/**
 * Support for use with Pandas library, for Python obly, not for other language
 */
%extend griddb::RowSet {
    //Support iterator
    griddb::RowSet* __iter__() {
        return $self;
    }
}

/**
 * Typemap for RowSet::get_column_name Support for use with Pandas library
 * For Python obly, not for other language
 */
%typemap(in, numinputs = 0) (char*** listName, int* num) (char** listNameTmp, int numTmp) {
    $1 = &listNameTmp;
    $2 = &numTmp;
}

%typemap(argout, numinputs = 0, fragment="convertStrToObj") (char*** listName, int* num) {
    $result = PyList_New(*$2);
    if (*$2){
        for(int i = 0; i < *$2; i++) {
            PyList_SetItem($result, i, convertStrToObj((*$1)[i]));
        }
        free((void *)*$1);
    }
    return $result;
}

%typemap(freearg) (char*** listName, int* num) {
    if (*$2){
        for(int i = 0; i < *$2; i++) {
            free((*$1)[i]);
        }
        free((void *)*$1);
    }
}

//Read only attribute Container::type
%attribute(griddb::Container, int, type, get_type);
//Read only attribute GSException::is_timeout
%attribute(griddb::GSException, bool, is_timeout, is_timeout);
//Read only attribute PartitionController::partition_count
%attribute(griddb::PartitionController, int, partition_count, get_partition_count);
//Read only attribute RowKeyPredicate::partition_count
%attribute(griddb::RowKeyPredicate, GSType, key_type, get_key_type);
//Read only attribute RowSet::size
%attribute(griddb::RowSet, int32_t, size, size);
//Read only attribute RowSet::type
%attribute(griddb::RowSet, GSRowSetType, type, type);
//Read only attribute Store::partition_info
%attribute(griddb::Store, griddb::PartitionController*, partition_info, partition_info);
//Read only attribute ContainerInfo::name
%attribute(griddb::ContainerInfo, GSChar*, name, get_name, set_name);
//Read only attribute ContainerInfo::type
%attribute(griddb::ContainerInfo, GSContainerType, type, get_type, set_type);
//Read only attribute ContainerInfo::rowKeyAssign
%attribute(griddb::ContainerInfo, bool, row_key, get_row_key_assigned, set_row_key_assigned);
//Read only attribute ExpirationInfo::time
%attribute(griddb::ExpirationInfo, int, time, get_time, set_time);
//Read only attribute ExpirationInfo::unit
%attribute(griddb::ExpirationInfo, GSTimeUnit, unit, get_time_unit, set_time_unit);
//Read only attribute ExpirationInfo::divisionCount
%attribute(griddb::ExpirationInfo, int, division_count, get_division_count, set_division_count);

//Attribute ContainerInfo::columnInfoList
%extend griddb::ContainerInfo{
    %pythoncode %{
     __swig_getmethods__["column_info_list"] = get_column_info_list
     __swig_setmethods__["column_info_list"] = set_column_info_list
    %}    
};

/**
 * Typemap for Container::multi_put
 */
%typemap(in, fragment = "convertObjectToFieldWithType") (griddb::Row** listRowdata, int rowCount) {
    if(!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }

    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    if($2 > 0) {
        GSType* typeList = arg1->getGSTypeList();

        $1 = (griddb::Row**)malloc($2 * sizeof(griddb::Row*));
        int length;
        for (int i = 0; i < $2; i++) {
            PyObject* rowTmp = PyList_GetItem($input, i);
            length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
            if (length != arg1->getColumnCount()) {
                $2 = i;
                %variable_fail(1, "Row", "num row is different with container info");
            }
            $1[i] = new griddb::Row(length);
            Field *tmpField = $1[i]->get_field_ptr();
            for(int k = 0; k < length; k++) {
                GSType type = typeList[k];
                PyObject* fieldObj = PyList_GetItem(rowTmp, k);
                if(!(convertObjectToFieldWithType(tmpField[k], fieldObj, type))) {
                    $2 = i+1;
                    char gsType[200];
                    sprintf(gsType, "Invalid value for column %d, type should be : %d", k, type);
                    PyErr_SetString(PyExc_ValueError, gsType);
                    SWIG_fail;
                } 
            }
        }
    }
}

%typemap(freearg) (griddb::Row** listRowdata, int rowCount) {
    if ($1) {
        for (int i = 0; i < $2; i++) {
            if ($1[i]) {
                delete $1[i];
            }
        }
        free($1);
    }
}
 
//attribute ContainerInfo::column_info_list
%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (ColumnInfoList columnInfoList) {

    if(!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int res;
    char* v = 0;
    bool vbool;
    int *alloc = (int*) malloc(sizeof(int));
    if(alloc == NULL) {
        return false;
    }
    memset(alloc, 0, sizeof(int));
    size_t size = 0;
    size = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    GSColumnInfo* containerInfo;
    if(size) {
        containerInfo = (GSColumnInfo*) malloc(size * sizeof(GSColumnInfo));
        if(containerInfo == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation for set column_info_list is error");
            SWIG_fail;
        }
        for (int i =0; i < size; i++) {
            PyObject* columInfoList = PyList_GetItem($input, i);
            if(!PyList_Check(columInfoList)) {
                PyErr_SetString(PyExc_ValueError, "Expected a List");
                SWIG_fail;
            }
            size_t sizeColumn = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
%#if GS_COMPATIBILITY_SUPPORT_3_5
            if (sizeColumn < 3) {
                PyErr_SetString(PyExc_ValueError, "Expect column info has 3 elements");
                SWIG_fail;
            }

            res = SWIG_AsCharPtrAndSize(PyList_GetItem(columInfoList, 0), &v, &size, alloc);
            if (!SWIG_IsOK(res)) {
                return false;
            }
            containerInfo[i].name = v;
            containerInfo[i].type = PyLong_AsLong(PyList_GetItem(columInfoList, 1));
            containerInfo[i].options =  PyLong_AsLong(PyList_GetItem(columInfoList, 2));

%#else
            if (sizeColumn < 2) {
                PyErr_SetString(PyExc_ValueError,"Expect column info has 2 elements");
                SWIG_fail;
            }
            res = SWIG_AsCharPtrAndSize(PyList_GetItem(columInfoList, 0), &v, &size, alloc);
            if (!SWIG_IsOK(res)) {
                return false;
            }
            containerInfo[i].name = v;
            containerInfo[i].type = PyLong_AsLong(PyList_GetItem(columInfoList, 1));
%#endif
        }
    }
    ColumnInfoList infolist;
    infolist.columnInfo = containerInfo;
    infolist.size = size;
    $1 = infolist;
}

%typemap(freearg) (ColumnInfoList columnInfoList) {
    size_t size = $1.size;    

    for (int i =0; i < size; i++) {
        if ($1.columnInfo[i].name) {
            %delete_array($1.columnInfo[i].name);
        }
    }
    if ($1.columnInfo) {
        free ((void *)$1.columnInfo);
    }

}

%typemap(out, fragment="convertStrToObj") (ColumnInfoList) {
    ColumnInfoList data = $1;
    size_t size = data.size;
    $result = PyList_New(size);
    if($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for column_info_list is error");
        SWIG_fail;
    }
    for (int i = 0; i < size; i++) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
        PyObject* info = PyList_New(3);
        PyList_SetItem(info, 0, convertStrToObj((data.columnInfo)[i].name));
        PyList_SetItem(info, 1, PyInt_FromLong((data.columnInfo)[i].type));
        PyList_SetItem(info, 2, PyInt_FromLong((data.columnInfo)[i].options));
%#else
        PyObject* info = PyList_New(2);
        PyList_SetItem(info, 0, convertStrToObj((data.columnInfo)[i].name));
        PyList_SetItem(info, 1, PyInt_FromLong((data.columnInfo)[i].type));
%#endif
        PyList_SetItem($result, i, info);
    }
}

/**
 * Type map for Rowset::next()
 */
%typemap(in, numinputs = 0) (GSRowSetType* type, griddb::Row* row, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) 
    (GSRowSetType typeTmp, bool hasNextRowTmp,
            griddb::QueryAnalysisEntry* queryAnalysisTmp, griddb::AggregationResult* aggResultTmp) {
    $1 = &typeTmp;
    $2 = new griddb::Row();
    hasNextRowTmp = true;
    $3 = &hasNextRowTmp;
    queryAnalysisTmp= new griddb::QueryAnalysisEntry(NULL);
    $4 = &queryAnalysisTmp;
    aggResultTmp = new griddb::AggregationResult(NULL);
    $5 = &aggResultTmp;
}

%typemap(argout, fragment = "convertFieldToObject") (GSRowSetType* type, griddb::Row* row, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {

    std::shared_ptr<griddb::AggregationResult>* agg;
    std::shared_ptr<griddb::QueryAnalysisEntry>* queryAnaly;

    PyObject *resultobj;
    PyObject *outList;
    std::shared_ptr<  griddb::AggregationResult > *smartresult;
    std::shared_ptr< griddb::QueryAnalysisEntry > *smartresult2;
    switch(*$1) {
        case (GS_ROW_SET_CONTAINER_ROWS):
            if (*$3 == false) {
                $result= NULL;
            } else {
                outList = PyList_New($2->get_count());
                if(outList == NULL) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                    SWIG_fail;
                }
                int i;
                for(int i = 0; i < $2->get_count(); i++) {
                    PyList_SetItem(outList, i, convertFieldToObject($2->get_field_ptr()[i]));
                }
                $result = outList;
            }
            break;
        case (GS_ROW_SET_AGGREGATION_RESULT):
            if (*$3 == false) {
                PyErr_SetNone(PyExc_StopIteration);
                $result= NULL;

            } else {
                smartresult = *$5 ? new std::shared_ptr<  griddb::AggregationResult >(*$5 SWIG_NO_NULL_DELETER_0) : 0;
                resultobj = SWIG_NewPointerObj(SWIG_as_voidptr(smartresult), SWIGTYPE_p_std__shared_ptrT_griddb__AggregationResult_t, 0 | SWIG_POINTER_OWN);
                $result = resultobj;
            }
            break;
        default:
            smartresult2 = *$4 ? new std::shared_ptr<  griddb::QueryAnalysisEntry >(*$4 SWIG_NO_NULL_DELETER_0) : 0;
            resultobj = SWIG_NewPointerObj(SWIG_as_voidptr(smartresult2), SWIGTYPE_p_std__shared_ptrT_griddb__QueryAnalysisEntry_t, 0 | SWIG_POINTER_OWN);
            $result = resultobj;

            break;
    }
    return $result;
}

%typemap(freearg) (GSRowSetType* type, griddb::Row* row, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {
    
    if ($2) {
        delete $2;
    }

    if (*$4) {
        delete *$4;
    }
    
    if ($5) {
        delete *$5;
    }
}
