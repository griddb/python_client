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
#include <limits>
%}
%ignore griddb::Row;
%ignore griddb::Container::getGSTypeList;
%ignore griddb::Container::getColumnCount;
%ignore griddb::RowSet::next_row;
%ignore griddb::RowSet::get_next_query_analysis;
%ignore griddb::RowSet::get_next_aggregation;
%ignore griddb::ContainerInfo::ContainerInfo(GSContainerInfo* containerInfo);

%pythonbegin %{
from enum import IntEnum
%}

%pythoncode {
class ContainerType(IntEnum):
    def __int__(self):
        return self._value
    COLLECTION = 0
    TIME_SERIES = 1
class IndexType(IntEnum):
    def __int__(self):
        return int(self.value)
    DEFAULT = -1
    TREE = 1 << 0
    HASH = 1 << 1
    SPATIAL = 1 << 2
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
    def __int__(self):
        return self._value
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
%#if GS_COMPATIBILITY_SUPPORT_3_5
    NULL = -1
%#endif

class TypeOption(IntEnum):
    def __int__(self):
        return int(self.value)
    NULLABLE = 1 << 1
    NOT_NULL = 1 << 2
}

%include <attribute.i>

#define UTC_TIMESTAMP_MAX 253402300799.999

//Support keyword arguments
%feature("autodoc", "0");

/**
 * Support find sub-string from string.
 * Use for create UTC datetime object in Python
 */

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

%fragment("convertTimestampToObject", "header") {
static PyObject* convertTimestampToObject(GSTimestamp* timestamp, bool timestamp_to_float = true) {
    // In C-API there is function PyDateTime_FromTimestamp convert from datetime to local datetime (not UTC).
    // But GridDB use UTC datetime => use the string output from gsFormatTime to convert to UTC datetime
    if (timestamp_to_float) {
        return PyFloat_FromDouble(((double)(*timestamp)) / 1000);
    }

    if (!PyDateTimeAPI) {
        PyDateTime_IMPORT;
    }
    PyObject *dateTime = NULL;
    size_t bufSize = 100;
    static GSChar strBuf[100] = {0};
    gsFormatTime(*timestamp, strBuf, bufSize);

    //Date format is YYYY-MM-DDTHH:mm:ss.sssZ
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int miliSecond;
    int microSecond;
    sscanf(strBuf, "%d-%d-%dT%d:%d:%d.%dZ", &year, &month, &day, &hour, &minute, &second, &miliSecond);
    microSecond = miliSecond * 1000;
    dateTime = PyDateTime_FromDateAndTime(year, month, day, hour, minute, second, microSecond);
    return dateTime;
}
}

/*
* fragment to support converting data for GSRow
*/
%fragment("convertFieldToObject", "header",
        fragment = "convertStrToObj", fragment = "convertTimestampToObject") {
static PyObject* convertFieldToObject(griddb::Field &field, bool timestamp_to_float = true) {
    PyObject* list;
    int listSize, i;
    void* arrayPtr;

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
            return convertTimestampToObject(&field.value.asTimestamp, timestamp_to_float);
        }
%#if GS_COMPATIBILITY_SUPPORT_3_5
        case GS_TYPE_NULL:
            return Py_None;
%#endif
        case GS_TYPE_BYTE:
            return PyInt_FromLong(field.value.asByte);
        case GS_TYPE_SHORT:
            return PyInt_FromLong(field.value.asShort);
        case GS_TYPE_GEOMETRY:
            return convertStrToObj(field.value.asGeometry);
        case GS_TYPE_INTEGER_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asIntegerArray.size;
            arrayPtr = (void*) field.value.asIntegerArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asInteger;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyInt_FromLong(*((int32_t *)arrayPtr + i)));
            }
            return list;

        case GS_TYPE_STRING_ARRAY:
            GSChar** arrString;
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asStringArray.size;
            arrString = (GSChar**) field.value.asStringArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrString = (GSChar**) field.value.asArray.elements.asString;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, convertStrToObj(arrString[i]));
            }
            return list;

        case GS_TYPE_BOOL_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asBoolArray.size;
            arrayPtr = (void*) field.value.asBoolArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asBool;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyBool_FromLong(*((bool *)arrayPtr + i)));
            }
            return list;
        case GS_TYPE_BYTE_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asByteArray.size;
            arrayPtr = (void*) field.value.asByteArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asByte;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyInt_FromLong(*((int8_t *)arrayPtr + i)));
            }
            return list;
        case GS_TYPE_SHORT_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asShortArray.size;
            arrayPtr = (void*) field.value.asShortArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asShort;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyInt_FromLong(*((int16_t *)arrayPtr + i)));
            }
            return list;
        case GS_TYPE_LONG_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asLongArray.size;
            arrayPtr = (void*) field.value.asLongArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asLong;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyLong_FromLong(*((int64_t *)arrayPtr + i)));
            }
            return list;
        case GS_TYPE_FLOAT_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asFloatArray.size;
            arrayPtr = (void*) field.value.asFloatArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asFloat;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyFloat_FromDouble(static_cast<double>(*((float *)arrayPtr + i))));
            }
            return list;
        case GS_TYPE_DOUBLE_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asDoubleArray.size;
            arrayPtr = (void*) field.value.asDoubleArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asDouble;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, PyFloat_FromDouble(*((double *)arrayPtr + i)));
            }
            return list;
        case GS_TYPE_TIMESTAMP_ARRAY:

%#if GS_COMPATIBILITY_VALUE_1_1_106
            listSize = field.value.asTimestampArray.size;
            arrayPtr = (void*) field.value.asTimestampArray.elements;
%#else
            listSize = field.value.asArray.length;
            arrayPtr = (void*) field.value.asArray.elements.asTimestamp;
%#endif
            list = PyList_New(listSize);
            for (i = 0; i < listSize; i++) {
                PyList_SetItem(list, i, convertTimestampToObject(((GSTimestamp *)arrayPtr + i), timestamp_to_float));
            }
            return list;
        default:
            return NULL;
    }

    return NULL;
}
}

/**
 * Support convert type from object to GSTimestamp: input in target language can be :
 * datetime object, string or float
 */
%fragment("convertObjectToGSTimestamp", "header", fragment = "convertObjectToFloat") {
static bool convertObjectToGSTimestamp(PyObject* value, GSTimestamp* timestamp) {
    int year, month, day, hour, minute, second, milliSecond, microSecond;
    size_t size = 0;
    int res;
    char* v = 0;
    bool vbool;
    int alloc;
    char s[30];
    GSBool retConvertTimestamp;

    if (PyBool_Check(value)) {
        return false;
    }
    if (!PyDateTimeAPI) {
        PyDateTime_IMPORT;
    }
    float floatTimestamp;
    double utcTimestamp;
    if (PyDateTime_Check(value)) {
        // Input is Python utc datetime object
        year = PyDateTime_GET_YEAR(value);
        month = PyDateTime_GET_MONTH(value);
        day = PyDateTime_GET_DAY(value);
        hour = PyDateTime_DATE_GET_HOUR(value);
        minute = PyDateTime_DATE_GET_MINUTE(value);
        second = PyDateTime_DATE_GET_SECOND(value);
        milliSecond = PyDateTime_DATE_GET_MICROSECOND(value)/1000;
        sprintf(s, "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", year, month, day, hour, minute, second, milliSecond);
        retConvertTimestamp = gsParseTime(s, timestamp);
        if (retConvertTimestamp == GS_FALSE) {
            return false;
        }
        return true;
    } else if (checkPyObjIsStr(value)) {

        // Input is datetime string: ex
        res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);

        if (!SWIG_IsOK(res)) {
           return false;
        }
        // error when string len is too short
        if (strlen(v) < 19) {
            if (alloc != SWIG_OLDOBJ) {
                free(v);
            }
            return false;
        }
        // this is for convert python's string datetime (YYYY-MM-DDTHH:mm:ss:sssZ)
        // to griddb's string datetime (YYYY-MM-DDTHH:mm:ss.sssZ)
        v[19] = '.';
        //Date format is YYYY-MM-DDTHH:mm:ss.sssZ
        retConvertTimestamp = gsParseTime(v, timestamp);
        if (alloc != SWIG_OLDOBJ) {
            free(v);
        }

        return (retConvertTimestamp == GS_TRUE);
    } else if (PyFloat_Check(value)) {
        // Input is python utc timestamp
        //utcTimestamp = PyFloat_AsDouble(value);
        vbool = convertObjectToDouble(value, &utcTimestamp);
        if (!vbool) {
            return false;
        }
        *timestamp = utcTimestamp * 1000;
        if (utcTimestamp > UTC_TIMESTAMP_MAX) {
            return false;
        }
        return true;
    } else if (PyLong_Check(value)) {
        utcTimestamp = PyLong_AsLong(value);
        if (utcTimestamp > UTC_TIMESTAMP_MAX) {
            return false;
        }
        *timestamp = utcTimestamp * 1000;
        return true;
    } else {
        // Invalid input
        return false;
    }
}
}

/**
 * Support convert type from object to Bool. input in target language can be :
 * integer or boolean
 */
%fragment("convertObjectToBool", "header", fragment = "SWIG_AsVal_bool", fragment = "SWIG_AsVal_int") {
static bool convertObjectToBool(PyObject* value, bool* boolValPtr) {
    int checkConvert = 0;
    if (PyInt_Check(value)) {
        //input can be integer
        int intVal ;
        checkConvert = SWIG_AsVal_int(value, &intVal);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        *boolValPtr = (intVal != 0);
        return true;
    } else {
        //input is boolean
        checkConvert = SWIG_AsVal_bool(value, boolValPtr);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        return true;
    }
}
}

/**
 * Support convert type from object to Float. input in target language can be :
 * float or integer
 */
%fragment("convertObjectToDouble", "header") {
static bool convertObjectToDouble(PyObject* value, double* floatValPtr) {
    int checkConvert = 0;
    if (PyBool_Check(value)) {
        return false;
    }
    if (PyInt_Check(value)) {
        //input can be integer
        long int intVal;
        checkConvert = SWIG_AsVal_long(value, &intVal);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        *floatValPtr = intVal;
        //When input value is integer, it should be between -9007199254740992(-2^53)/9007199254740992(2^53).
        return (-9007199254740992 <= intVal && 9007199254740992 >= intVal);
    } else {
        //input is float
        if (!PyFloat_Check(value)) {
            return false;
        }
        *floatValPtr = PyFloat_AsDouble(value);
        return true;
    }
}
}

/**
 * Support convert type from object to Float. input in target language can be :
 * float or integer
 */
%fragment("convertObjectToFloat", "header") {
static bool convertObjectToFloat(PyObject* value, float* floatValPtr) {
    int checkConvert = 0;
    if (PyBool_Check(value)) {
        return false;
    }
    if (PyInt_Check(value)) {
        //input can be integer
        long int intVal;
        checkConvert = SWIG_AsVal_long(value, &intVal);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        *floatValPtr = intVal;
        //When input value is integer, it should be between -16777216(-2^24)/16777216(2^24).
        return (-16777216 <= intVal && 16777216 >= intVal);

    } else {
        //input is float
        if (!PyFloat_Check(value)) {
            return false;
        }
        *floatValPtr = PyFloat_AsDouble(value);
        return true;
    }
}
}

/**
 * Support convert type from object to Blob. input in target language can be :
 * byte array or string
 * Need to free data.
 */
%fragment("convertObjectToBlob", "header", fragment = "checkPyObjIsStr") {
static bool convertObjectToBlob(PyObject* value, size_t* size, void** data) {
    GSChar* blobData;
    GSChar* tmpBlobData;
    int res;
    if (PyByteArray_Check(value)) {
        *size = PyByteArray_Size(value);
        if (*size > 0) {
            blobData = (GSChar*) malloc(sizeof(GSChar) * (*size));
            if (blobData == NULL) {
                return false;
            }
            memset(blobData, 0x0, sizeof(GSChar) * (*size));
            memcpy(blobData, PyByteArray_AsString(value), *size);
            *data = (void*) blobData;
        }
        return true;
    } else if (checkPyObjIsStr(value)) {
        int alloc;
        res = SWIG_AsCharPtrAndSize(value, &blobData, size, &alloc);
        if (!SWIG_IsOK(res)) {
           return false;
        }
        if (alloc == SWIG_OLDOBJ) {
            //swig reuse old memory, this memory is used by swig
            //we will create new and duplicate this memory
            blobData = strdup(blobData);
        }
        //Ignore null character
        *size = *size - 1;
        *data = (void*) blobData;
        return true;
    }
    return false;
}
}
/**
 * Support covert Field from PyObject* to C Object with specific type
 */
%fragment("convertObjectToFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize",
        fragment = "checkPyObjIsStr", fragment = "convertObjToStr", fragment = "convertObjectToDouble",
        fragment = "convertObjectToGSTimestamp", fragment = "SWIG_AsVal_bool",
        fragment = "convertObjectToBlob", fragment = "convertObjectToBool",
        fragment = "convertObjectToFloat") {
    static bool convertObjectToFieldWithType(griddb::Field &field, PyObject* value, GSType type) {
        size_t size = 0;
        int res;
        char* v = 0;
        bool vbool;
        int alloc;
        field.type = type;

        if (value == Py_None) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
            field.type = GS_TYPE_NULL;
            return true;
%#else
        //Not support NULL
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
        PyObject* objectsRepresentation;
        int arraySize, i;
        void* arrayPtr;
        int tmpInt;
        long double tmpLongDouble;
        double tmpDouble; //support convert to double, double array
        float tmpFloat; //support convert to float, float array
        bool inBorderVal = false;
        bool inRange = false;
        switch(type) {
            case (GS_TYPE_STRING):
                if (!checkPyObjIsStr(value)) {
                    return false;
                }
                res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);

                if (!SWIG_IsOK(res)) {
                    return false;
                }
                if (alloc == SWIG_OLDOBJ) {
                    //swig reuse old memory, this memory is used by swig
                    //we will create new and duplicate this memory
                    v = strdup(v);
                }

                field.value.asString = v;
                field.type = GS_TYPE_STRING;
                break;

            case (GS_TYPE_BOOL):
                vbool = convertObjectToBool(value, (bool*) &field.value.asBool);
                if (!vbool) {
                    return false;
                }
                break;

            case (GS_TYPE_BYTE):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_int(value, &tmpInt);
                if (!SWIG_IsOK(checkConvert) ||
                    tmpInt < std::numeric_limits<int8_t>::min() ||
                    tmpInt > std::numeric_limits<int8_t>::max()) {
                    return false;
                }
                field.value.asByte = (int8_t) tmpInt;
                break;

            case (GS_TYPE_SHORT):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_int(value, &tmpInt);
                if (!SWIG_IsOK(checkConvert) ||
                    tmpInt < std::numeric_limits<int16_t>::min() ||
                    tmpInt > std::numeric_limits<int16_t>::max()) {
                    return false;
                }
                field.value.asShort = (int16_t) tmpInt;
                break;

            case (GS_TYPE_INTEGER):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_int(value, &field.value.asInteger);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                break;

            case (GS_TYPE_LONG):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_long(value, &field.value.asLong);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                //Because swig function above not check overflow of long type.
                break;

            case (GS_TYPE_FLOAT):
                vbool = convertObjectToFloat(value, &tmpFloat);
                if (!vbool) {
                    return false;
                }
                field.value.asFloat = tmpFloat;
                break;
            case (GS_TYPE_DOUBLE):
                vbool = convertObjectToDouble(value, &tmpDouble);
                if (!vbool) {
                    return false;
                }
                field.value.asDouble = tmpDouble;
                break;

            case (GS_TYPE_TIMESTAMP):
                return convertObjectToGSTimestamp(value, &field.value.asTimestamp);
                break;
            case (GS_TYPE_BLOB):
                vbool = convertObjectToBlob(value, &field.value.asBlob.size, (void**) &field.value.asBlob.data);
                if (!vbool) {
                    return false;
                }
                break;

            case (GS_TYPE_STRING_ARRAY):
                GSChar** arrString;
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asStringArray.size = arraySize;
                field.value.asStringArray.elements = (GSChar**) malloc(arraySize * sizeof(GSChar*));
                if (field.value.asStringArray.elements == NULL) {
                    return false;
                }

                arrString = (GSChar**) field.value.asStringArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asString = (GSChar**) malloc(arraySize * sizeof(GSChar*));
                if (field.value.asArray.elements.asString == NULL) {
                    return false;
                }

                arrString = (GSChar**) field.value.asArray.elements.asString;
%#endif
                for (i = 0; i < arraySize; i++) {
                    if (!checkPyObjIsStr(PyList_GetItem(value, i))) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                    for (int j = 0; j < field.value.asStringArray.size; j++) {
                        free(const_cast<GSChar*> (field.value.asStringArray.elements[j]));
                    }
                    free((void*) field.value.asStringArray.elements);
                    field.value.asStringArray.elements = NULL;
%#else
                    for (int j = 0; j < i; j++) {
                        free(const_cast<GSChar*> (field.value.asArray.elements.asString[j]));
                    }
                    free((void*) field.value.asArray.elements.asString);
                    field.value.asArray.elements.asString = NULL;
%#endif
                        return false;
                    }
                    res = SWIG_AsCharPtrAndSize(PyList_GetItem(value, i), (arrString + i), &size, &alloc);
                    if (!SWIG_IsOK(res)) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        for (int j = 0; j < field.value.asStringArray.size; j++) {
                            free(const_cast<GSChar*> (field.value.asStringArray.elements[j]));
                        }
                        free((void*) field.value.asStringArray.elements);
                        field.value.asStringArray.elements = NULL;
%#else
                        for (int j = 0; j < i; j++) {
                            free(const_cast<GSChar*> (field.value.asArray.elements.asString[j]));
                        }
                        free((void*) field.value.asArray.elements.asString);
                        field.value.asArray.elements.asString = NULL;
%#endif
                       return false;
                    }
                    if (alloc == SWIG_OLDOBJ) {
                        arrString[i] = strdup(arrString[i]);
                    }

                }
                break;
            case (GS_TYPE_GEOMETRY):
                if (!checkPyObjIsStr(value)) {
                    return false;
                }
                res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);

                if (!SWIG_IsOK(res)) {
                    return false;
                }
                if (alloc == SWIG_OLDOBJ) {
                    //swig reuse old memory, this memory is used by swig
                    //we will create new and duplicate this memory
                    v = strdup(v);
                }
                
                field.value.asGeometry = v;
                break;

            case (GS_TYPE_INTEGER_ARRAY):
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asIntegerArray.size = arraySize;
                field.value.asIntegerArray.elements = (const int32_t *) malloc(arraySize * sizeof(int32_t));
                if (field.value.asIntegerArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asIntegerArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asInteger = (const int32_t *) malloc(arraySize * sizeof(int32_t));
                if (field.value.asArray.elements.asInteger == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asInteger;
%#endif
                for (i = 0; i < arraySize; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), ((int32_t *)arrayPtr + i));
                    if (!SWIG_IsOK(checkConvert) || vbool) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asIntegerArray.elements);
                        field.value.asIntegerArray.elements = NULL;
%#else
                        free((void*)field.value.asArray.elements.asInteger);
                        field.value.asArray.elements.asInteger = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_BOOL_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asBoolArray.size = arraySize;
                field.value.asBoolArray.elements = (const GSBool *) malloc(arraySize * sizeof(GSBool));
                if (field.value.asBoolArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asBoolArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asBool = (const GSBool *) malloc(arraySize * sizeof(GSBool));
                if (field.value.asArray.elements.asBool == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asBool;
%#endif
                for (i = 0; i < arraySize; i++) {
                    vbool = convertObjectToBool(PyList_GetItem(value, i), ((bool *)arrayPtr + i));
                    if (!vbool) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asBoolArray.elements);
                        field.value.asBoolArray.elements = NULL:
%#else
                        free((void*)field.value.asArray.elements.asBool);
                        field.value.asArray.elements.asBool = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_BYTE_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asByteArray.size = arraySize;
                field.value.asByteArray.elements = (const int8_t *) malloc(arraySize * sizeof(int8_t));
                if (field.value.asByteArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asByteArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asByte = (const int8_t *) malloc(arraySize * sizeof(int8_t));
                if (field.value.asArray.elements.asByte == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asByte;
%#endif
                for (i = 0; i < arraySize; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &tmpInt);
                    *(((int8_t*)arrayPtr + i)) = (int8_t)tmpInt;
                     if (vbool || !SWIG_IsOK(checkConvert) ||
                        tmpInt < std::numeric_limits<int8_t>::min() ||
                        tmpInt > std::numeric_limits<int8_t>::max()) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asByteArray.elements);
                        field.value.asByteArray.elements = NULL;
%#else
                        free((void*)field.value.asArray.elements.asByte);
                        field.value.asArray.elements.asByte = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_SHORT_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asShortArray.size = arraySize;
                field.value.asShortArray.elements = (const int16_t *) malloc(arraySize * sizeof(int16_t));
                if (field.value.asShortArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asShortArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asShort = (const int16_t *) malloc(arraySize * sizeof(int16_t));
                if (field.value.asArray.elements.asShort == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asShort;
%#endif
                for (i = 0; i < arraySize; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &tmpInt);
                    *(((int16_t*)arrayPtr + i)) = (int16_t)tmpInt;
                    if (vbool || !SWIG_IsOK(checkConvert) ||
                        tmpInt < std::numeric_limits<int16_t>::min() ||
                        tmpInt > std::numeric_limits<int16_t>::max()) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asShortArray.elements);
                        field.value.asShortArray.elements = NULL;
%#else
                        free((void*)field.value.asArray.elements.asShort);
                        field.value.asArray.elements.asShort = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_LONG_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asLongArray.size = arraySize;
                field.value.asLongArray.elements = (const int64_t *) malloc(arraySize * sizeof(int64_t));
                if (field.value.asLongArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asLongArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asLong = (const int64_t *) malloc(arraySize * sizeof(int64_t));
                if (field.value.asArray.elements.asLong == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asLong;
%#endif
                for (i = 0; i < arraySize; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_long(PyList_GetItem(value, i), ((int64_t *)arrayPtr + i));
                    if (!SWIG_IsOK(checkConvert) || vbool) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asLongArray.elements);
                        field.value.asLongArray.elements = NULL;
%#else
                        free((void*)field.value.asArray.elements.asLong);
                        field.value.asArray.elements.asLong = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_FLOAT_ARRAY:
                float* floatPtr;
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                floatPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asFloatArray.size = arraySize;
                field.value.asFloatArray.elements = (const float *) malloc(arraySize * sizeof(float));
                if (field.value.asFloatArray.elements == NULL) {
                    return false;
                }
                floatPtr = (float*) field.value.asFloatArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asFloat = (const float *) malloc(arraySize * sizeof(float));
                if (field.value.asArray.elements.asFloat == NULL) {
                    return false;
                }
                floatPtr = (float*) field.value.asArray.elements.asFloat;
%#endif

                for (i = 0; i < arraySize; i++) {
                    vbool = convertObjectToFloat(PyList_GetItem(value, i), &tmpFloat);
                    floatPtr[i] = tmpFloat;
                    if (!vbool) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asFloatArray.elements);
                        field.value.asFloatArray.elements = NULL;
%#else
                        free((void*)field.value.asArray.elements.asFloat);
                        field.value.asArray.elements.asFloat = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_DOUBLE_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asDoubleArray.size = arraySize;
                field.value.asDoubleArray.elements = (const double *) malloc(arraySize * sizeof(double));
                if (field.value.asDoubleArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asDoubleArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asDouble = (const double *) malloc(arraySize * sizeof(double));
                if (field.value.asArray.elements.asDouble == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asDouble;
%#endif
                for (i = 0; i < arraySize; i++) {
                    vbool = convertObjectToDouble(PyList_GetItem(value, i), &tmpDouble);
                    *((double *)arrayPtr + i) = tmpDouble;
                    if (!vbool){
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asDoubleArray.elements);
                        field.value.asDoubleArray.elements = NULL;
%#else
                        free((void*)field.value.asArray.elements.asDouble);
                        field.value.asArray.elements.asDouble = NULL;
%#endif
                        return false;
                    }
                }
                break;
            case GS_TYPE_TIMESTAMP_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                arraySize = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                arrayPtr = NULL;
%#if GS_COMPATIBILITY_VALUE_1_1_106
                field.value.asTimestampArray.size = arraySize;
                field.value.asTimestampArray.elements = (const GSTimestamp *) malloc(arraySize * sizeof(GSTimestamp));
                if (field.value.asTimestampArray.elements == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asTimestampArray.elements;
%#else
                field.value.asArray.length = arraySize;
                field.value.asArray.elements.asTimestamp = (const GSTimestamp *) malloc(arraySize * sizeof(GSTimestamp));
                if (field.value.asArray.elements.asTimestamp == NULL) {
                    return false;
                }
                arrayPtr = (void*) field.value.asArray.elements.asTimestamp;
%#endif
                bool checkRet;
                for (i = 0; i < arraySize; i++) {
                    checkRet = convertObjectToGSTimestamp(PyList_GetItem(value, i), ((GSTimestamp *)arrayPtr + i));
                    if (!checkRet) {
%#if GS_COMPATIBILITY_VALUE_1_1_106
                        free((void*)field.value.asTimestampArray.elements);
                        field.value.asTimestampArray.elements = NULL:
%#else
                        free((void*)field.value.asArray.elements.asTimestamp);
                        field.value.asArray.elements.asTimestamp = NULL;
%#endif
                        return false;
                    }
                }
                break;
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
        $1 = (GSColumnInfo *) malloc($2 * sizeof(GSColumnInfo));
        alloc = (int*) malloc($2 * sizeof(int));

        if ($1 == NULL || alloc == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        memset($1, 0x0, $2 * sizeof(GSColumnInfo));
        memset(alloc, 0x0, $2 * sizeof(int));

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

            if (!PyInt_Check(PyList_GetItem(list, 1))) {
                PyErr_SetString(PyExc_ValueError, "Expected an Integer as column type");
                SWIG_fail;
            }

            $1[i].name = strdup(v);
            free((void*) v);
            $1[i].type = (int) PyInt_AsLong(PyList_GetItem(list, 1));
%#if GS_COMPATIBILITY_SUPPORT_3_5
            int tupleLength = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(list)));
            //Case user input option parameter
            if (tupleLength == 3) {
                if (!PyInt_Check(PyList_GetItem(list, 2))) {
                    PyErr_SetString(PyExc_ValueError, "Expected an Integer as column option");
                    SWIG_fail;
                }
                $1[i].options = (int) PyInt_AsLong(PyList_GetItem(list, 2));
                if ($1[i].options != GS_TYPE_OPTION_NULLABLE && $1[i].options != GS_TYPE_OPTION_NOT_NULL) {
                    PyErr_SetString(PyExc_ValueError, "Invalid value for column option");
                    SWIG_fail;
                }
            } else if (tupleLength == 2) {
                $1[i].options = 0;
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
        for (int i = 0; i < $2; i++) {
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

%typemap(doc, name = "column_info_list") (const GSColumnInfo* props, int propsCount) "list[list[string, Type, TypeOption]]";
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
        $1 = (GSPropertyEntry *) malloc($2 * sizeof(GSPropertyEntry));
        alloc = (int*) malloc($2 * 2 * sizeof(int));
        if ($1 == NULL || alloc == NULL) {
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
        for (int i = 0; i < $2; i++) {
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
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        return NULL;
    }
    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    i = 0;
    if ($2 > 0) {
        $1 = (GSQuery**) malloc($2 * sizeof(GSQuery*));
        if ($1 == NULL) {
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

%typemap(doc, name = "query_list") (GSQuery* const* queryList, size_t queryCount) "list[Query] query_list";

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
        $1 = (int8_t *) malloc($2 * sizeof(int8_t));
        if ($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        i = 0;
        while (i < $2) {
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
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    $1 = NULL;
    i = 0;
    si = 0;
    if ($2 > 0) {
        pList = (GSRowKeyPredicateEntry*) malloc($2 * sizeof(GSRowKeyPredicateEntry));
        alloc = (int*) malloc($2 * sizeof(int));

        if (pList == NULL || alloc == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        memset(alloc, 0x0, $2 * sizeof(int));
        $1 = &pList;

        while (PyDict_Next($input, &si, &key, &val)) {
            GSRowKeyPredicateEntry *predicateEntry = &pList[i];
            res = SWIG_AsCharPtrAndSize(key, &v, &size, &alloc[i]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "containerName");
                free((void*) pList);
            }
            predicateEntry->containerName = v;
            //Get GSRowKeyPredicate pointer from RowKeyPredicate pyObject
            int newmem = 0;
            res = SWIG_ConvertPtrAndOwn(val, (void **) &vpredicate, $descriptor(std::shared_ptr<griddb::RowKeyPredicate>*), %convertptr_flags, &newmem);
            if (!SWIG_IsOK(res)) {
                %argument_fail(res, "$type", $symname, $argnum);
                free((void*) pList);
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

%typemap(freearg) (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount) (int i) {
    if ($1 && *$1) {
        for (int i = 0; i < $2; i++) {
            if (alloc$argnum[i] == SWIG_NEWOBJ) {
                %delete_array((*$1)[i].containerName);
            }
        }
        if (pList$argnum != NULL) {
            free((void *) pList$argnum);
        }
    }

    if (alloc$argnum) {
        free(alloc$argnum);
    }
}

/**
* Typemaps output for partition controller function
*/
%typemap(in, numinputs = 0) (const GSChar *const ** stringList, size_t *size) (GSChar **nameList1, size_t size1) {
    $1 = &nameList1;
    $2 = &size1;
}

%typemap(argout, numinputs = 0, fragment="convertStrToObj") (const GSChar *const ** stringList, size_t *size) (  int i, size_t size) {
    GSChar** nameList1 = *$1;
    size_t size = *$2;
    $result = PyList_New(size);
    for (int i = 0; i < size; i++) {
        PyObject *o = convertStrToObj(nameList1[i]);
        PyList_SetItem($result, i, o);
    }
}

%typemap(in, numinputs = 0) (const int **intList, size_t *size) (int *intList1, size_t size1) {
    $1 = &intList1;
    $2 = &size1;
}

%typemap(argout, numinputs = 0) (const int **intList, size_t *size) (int i, size_t size) {
    int* intList = *$1;
    size_t size = *$2;
    $result = PyList_New(size);
    for (int i = 0; i < size; i++) {
        PyObject *o = PyInt_FromLong(intList[i]);
        PyList_SetItem($result,i,o);
    }
}

%typemap(in, numinputs = 0) (const long **longList, size_t *size) (long *longList1, size_t size1) {
    $1 = &longList1;
    $2 = &size1;
}

%typemap(argout, numinputs = 0) (const long **longList, size_t *size) (int i, size_t size) {
    long* longList = *$1;
    size_t size = *$2;
    $result = PyList_New(size);
    for (int i = 0; i < size; i++) {
        PyObject *o = PyFloat_FromDouble(longList[i]);
        PyList_SetItem($result,i,o);
    }
}

%typemap(in, fragment = "convertObjectToBlob") (const GSBlob *fieldValue) {
    $1 = (GSBlob*) malloc(sizeof(GSBlob));
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }

    vbool = convertObjectToBlob(value, &$1->size, (void**) &$1->data);
    if (!vbool) {
        free((void*) $1);
        return false;
    }
}

%typemap(freearg) (const GSBlob *fieldValue) {
    if ($1) {
        if ($1->data) {
            free ((void*) $1->data);
        }
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
%typemap(in, numinputs = 0) (griddb::Field *agValue) (griddb::Field tmpAgValue){
    $1 = &tmpAgValue;
}
%typemap(argout, fragment = "convertFieldToObject") (griddb::Field *agValue) {
    $result = convertFieldToObject(*$1, arg1->timestamp_output_with_float);
}

/**
* Typemaps for update() function
*/
%typemap(in, fragment="convertObjectToFieldWithType") (griddb::Row *row) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = new griddb::Row(leng);
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    griddb::Field *tmpField = $1->get_field_ptr();

    if (leng != arg1->getColumnCount()) {
        %variable_fail(1, "Row", "num row is different with container info");
    }
    GSType* typeList = arg1->getGSTypeList();
    for (int i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if (!(convertObjectToFieldWithType(tmpField[i], PyList_GetItem($input, i), type))) {
            char gsType[200];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }
}

%typemap(freearg) (griddb::Row *row) {
    if ($1) {
        delete $1;
    }
}

/**
* Typemaps for put_row() function
*/
%typemap(in, fragment="convertObjectToFieldWithType") (griddb::Row *rowContainer) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = new griddb::Row(leng);
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    griddb::Field *tmpField = $1->get_field_ptr();

    if (leng != arg1->getColumnCount()) {
        %variable_fail(1, "Row", "num row is different with container info");
    }
    GSType* typeList = arg1->getGSTypeList();
    for (int i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if (!(convertObjectToFieldWithType(tmpField[i], PyList_GetItem($input, i), type))) {
            char gsType[200];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }
}

%typemap(freearg) (griddb::Row *rowContainer) {
    if ($1) {
        delete $1;
    }
}

%typemap(doc, name = "row") (griddb::Row *rowContainer) "list[object]";

/*
* typemap for get_row
*/

%typemap(in, fragment = "convertObjectToFieldWithType") (griddb::Field* keyFields)(griddb::Field field) {
    $1 = &field;
    if ($input == Py_None) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
        $1->type = GS_TYPE_NULL;
%#else
        %variable_fail(1, "String", "Not support for NULL");
%#endif
    } else {
        GSType* typeList = arg1->getGSTypeList();
        GSType type = typeList[0];
        if (!convertObjectToFieldWithType(*$1, $input, type)) {
            %variable_fail(1, "String", "can not convert to row field");
        }
    }
}

%typemap(freearg) (griddb::Field* keyFields) {
    if ($1) {
        if ($1->value.asString && $1->type == GS_TYPE_STRING) {
            %delete_array($1->value.asString);
        }
        if ($1->value.asBlob.data && $1->type == GS_TYPE_BLOB) {
            free((void*) $1->value.asBlob.data);
        }

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asIntegerArray.elements && $1->type == GS_TYPE_INTEGER_ARRAY) {
            free((void*) $1->value.asIntegerArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asInteger && $1->type == GS_TYPE_INTEGER_ARRAY) {
            free((void*) $1->value.asArray.elements.asInteger);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asStringArray.elements && $1->type == GS_TYPE_STRING_ARRAY) {
            for (int j = 0; j < $1->value.asStringArray.size; j++) {
                free(const_cast<GSChar*> ($1->value.asStringArray.elements[j]));
            }
            free((void*) $1->value.asStringArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asString && $1->type == GS_TYPE_STRING_ARRAY) {
            for (int j = 0; j < $1->value.asArray.length; j++) {
                free(const_cast<GSChar*> ($1->value.asArray.elements.asString[j]));
            }
            free((void*) $1->value.asArray.elements.asString);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asBoolArray.elements && $1->type == GS_TYPE_BOOL_ARRAY) {
            free((void*) $1->value.asBoolArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asBool && $1->type == GS_TYPE_BOOL_ARRAY) {
            free((void*) $1->value.asArray.elements.asBool);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asByteArray.elements && $1->type == GS_TYPE_BYTE_ARRAY) {
            free((void*) $1->value.asByteArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asByte && $1->type == GS_TYPE_BYTE_ARRAY) {
            free((void*) $1->value.asArray.elements.asByte);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asShortArray.elements && $1->type == GS_TYPE_SHORT_ARRAY) {
            free((void*) $1->value.asShortArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asShort && $1->type == GS_TYPE_SHORT_ARRAY) {
            free((void*) $1->value.asArray.elements.asShort);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asLongArray.elements && $1->type == GS_TYPE_LONG_ARRAY) {
            free((void*) $1->value.asLongArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asLong && $1->type == GS_TYPE_LONG_ARRAY) {
            free((void*) $1->value.asArray.elements.asLong);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asFloatArray.elements && $1->type == GS_TYPE_FLOAT_ARRAY) {
            free((void*) $1->value.asFloatArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asFloat && $1->type == GS_TYPE_FLOAT_ARRAY) {
            free((void*) $1->value.asArray.elements.asFloat);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asDoubleArray.elements && $1->type == GS_TYPE_DOUBLE_ARRAY) {
            free((void*) $1->value.asDoubleArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asDouble && $1->type == GS_TYPE_DOUBLE_ARRAY) {
            free((void*) $1->value.asArray.elements.asDouble);
        }
%#endif

%#if GS_COMPATIBILITY_VALUE_1_1_106
        if ($1->value.asTimestampArray.elements && $1->type == GS_TYPE_TIMESTAMP_ARRAY) {
            free((void*) $1->value.asTimestampArray.elements);
        }
%#else
        if ($1->value.asArray.elements.asTimestamp && $1->type == GS_TYPE_TIMESTAMP_ARRAY) {
            free((void*) $1->value.asArray.elements.asTimestamp);
        }
%#endif
    }
}

%typemap(doc, name = "key") (griddb::Field* keyFields) "object";

%typemap(in, numinputs = 0) (griddb::Row *rowdata) {
    $1 = new griddb::Row();
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
}

%typemap(freearg) (griddb::Row *rowdata) {
    if ($1) {
        delete $1;
    }
}

%typemap(argout, fragment = "convertFieldToObject") (griddb::Row *rowdata) {
    PyObject *outList = PyList_New($1->get_count());
    if (outList == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }

    for (int i = 0; i < $1->get_count(); i++) {
        PyList_SetItem(outList, i, convertFieldToObject($1->get_field_ptr()[i], arg1->timestamp_output_with_float));
    }
    $result = outList;
}

/**
 * Create typemap for RowKeyPredicate.set_range
 */
%typemap(in, fragment= "convertObjectToFieldWithType") (griddb::Field* startKey) {
    $1 = (griddb::Field*) malloc(sizeof(griddb::Field));
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    GSType type = arg1->get_key_type();
    if (!(convertObjectToFieldWithType(*$1, $input, type))) {
        %variable_fail(1, "String", "can not create row based on input");
    }
}

%typemap(freearg) (griddb::Field* startKey) {
    if ($1) {
        if ($1->value.asString && $1->type == GS_TYPE_STRING) {
            %delete_array($1->value.asString);
        }
        if ($1->value.asBlob.data && $1->type == GS_TYPE_BLOB) {
            free((void*) $1->value.asBlob.data);
        }
        free((void*) $1);
    }
}

%typemap(doc, name = "start") (griddb::Field* startKey) "object start";

%typemap(in, fragment= "convertObjectToFieldWithType") (griddb::Field* finishKey) {
    $1 = (griddb::Field *) malloc(sizeof(griddb::Field));
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }

    GSType type = arg1->get_key_type();
    if (!(convertObjectToFieldWithType(*$1, $input, type))) {
        %variable_fail(1, "String", "can not create row based on input");
    }
}

%typemap(freearg) (griddb::Field* finishKey) {
    if ($1) {
        if ($1->value.asString && $1->type == GS_TYPE_STRING) {
            %delete_array($1->value.asString);
        }
        if ($1->value.asBlob.data && $1->type == GS_TYPE_BLOB) {
            free((void*) $1->value.asBlob.data);
        }
        free((void*) $1);
    }
}

%typemap(doc, name = "end") (griddb::Field* finishKey) "object end";

/**
 * Typemap for RowKeyPredicate.get_range
 */
%typemap(in, numinputs = 0) (griddb::Field* startField, griddb::Field* finishField)
        (griddb::Field startKeyTmp, griddb::Field finishKeyTmp) {
    $1 = &startKeyTmp;
    $2 = &finishKeyTmp;
}

%typemap(argout, fragment="convertFieldToObject") (griddb::Field* startField, griddb::Field* finishField) {
    int length = 2;
    $result = PyList_New(2);
    if ($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    PyList_SetItem($result, 0, convertFieldToObject(*$1, arg1->timestamp_output_with_float));
    PyList_SetItem($result, 1, convertFieldToObject(*$2, arg1->timestamp_output_with_float));
}

/**
 * Typemap for RowKeyPredicate.set_distinct_keys
 */
%typemap(in, fragment="convertObjectToFieldWithType") (const griddb::Field *keys, size_t keyCount) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        return NULL;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        $1 = (griddb::Field *) malloc($2 * sizeof(griddb::Field));
        if ($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        GSType type = arg1->get_key_type();
        for (int i = 0; i< $2; i++) {
            if (!(convertObjectToFieldWithType($1[i], PyList_GetItem($input, i), type))) {
                %variable_fail(1, "String", "can not create row based on input");
            }
        }
    }
}

%typemap(freearg) (const griddb::Field *keys, size_t keyCount) {
    if ($1) {
        if ($2 > 0) {
            for (int i = 0; i< $2; i++) {
                griddb::Field* key = &$1[i];
                if (key->value.asString && key->type == GS_TYPE_STRING) {
                    %delete_array(key->value.asString);
                }
                if (key->value.asBlob.data && key->type == GS_TYPE_BLOB) {
                    free((void*) key->value.asBlob.data);
                }
            }
        }

        free((void*) $1);
    }
}

%typemap(doc, name = "keys") (const griddb::Field *keys, size_t keyCount) "list[object] keys";

/**
* Typemaps output for RowKeyPredicate.get_distinct_keys
*/
%typemap(in, numinputs = 0) (griddb::Field **keys, size_t* keyCount) (griddb::Field *keys1, size_t keyCount1) {
    $1 = &keys1;
    $2 = &keyCount1;
}

%typemap(argout, numinputs = 0, fragment="convertFieldToObject") (griddb::Field **keys, size_t* keyCount) (  int i, size_t size) {
    size_t size = *$2;
    $result = PyList_New(size);
    if ($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    griddb::Field* keyList = *($1);
    int num;
    for (num = 0; num < size; num++) {
        PyObject *o = convertFieldToObject(keyList[num], arg1->timestamp_output_with_float);
        PyList_SetItem($result, num, o);
    }
}

%typemap(freearg) (griddb::Field **keys, size_t* keyCount) {
    if ($1) {
        if ($2 > 0) {
            for (int i = 0; i< *$2; i++) {
                griddb::Field* key = $1[i];
                if (key->value.asString && key->type == GS_TYPE_STRING) {
                    %delete_array(key->value.asString);
                }
                if (key->value.asBlob.data && key->type == GS_TYPE_BLOB) {
                    free((void*) key->value.asBlob.data);
                }
            }
        }
        free((void*) *$1);
    }
}

/**
 * Typemaps for Store.multi_put
 */
%typemap(in, fragment="convertObjectToFieldWithType", fragment="convertObjToStr") (griddb::Row*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) () {
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $1 = NULL;
    $2 = NULL;
    $3 = NULL;
    $4 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    if ($4 > 0) {
        $1 = (griddb::Row***) malloc($4 * sizeof(griddb::Row**));

        $2 = (int*) malloc($4 * sizeof(int));
        $3 = (char **) malloc($4 * sizeof(char*));
        if ($1 == NULL || $2 == NULL || $3 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        int i = 0;
        int j = 0;
        //Init default null list row for each container
        j = 0;
        while (j < $4) {
            $1[j] = NULL;
            j++;
        }
        //End init
        Py_ssize_t si = 0;
        PyObject* containerName;
        PyObject* listRowContainer;
        griddb::ContainerInfo* containerInfoTmp;
        ColumnInfoList infoListTmp;
        while (PyDict_Next($input, &si, &containerName, &listRowContainer)) {
            int numRowOfContainer = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(listRowContainer)));
            $1[i] = (griddb::Row**) malloc(numRowOfContainer * sizeof(griddb::Row*));
            if ($1[i] == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                SWIG_fail;
            }
            //Init default null row
            j = 0;
            while (j < numRowOfContainer) {
                $1[i][j] = NULL;
                j++;
            }
            //End init
            $2[i] = numRowOfContainer;
            $3[i] = convertObjToStr(containerName);
            j = 0;
            int length;
            containerInfoTmp = arg1->get_container_info($3[i]);
            infoListTmp = containerInfoTmp->get_column_info_list();
            int* typeArr = (int*) malloc(infoListTmp.size * sizeof(int));
            if (containerInfoTmp == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                SWIG_fail;
            }
            if (typeArr == NULL) {
                delete containerInfoTmp;
                PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                SWIG_fail;
            }
            for (int m = 0; m < infoListTmp.size; m++) {
                typeArr[m] = infoListTmp.columnInfo[m].type;
            }
            while (j < numRowOfContainer) {
                PyObject* rowTmp = PyList_GetItem(listRowContainer, j);
                if (!PyList_Check(rowTmp)) {
                    PyErr_SetString(PyExc_ValueError, "Expected a List");
                    free((void *) typeArr);
                    delete containerInfoTmp;
                    SWIG_fail;
                }
                length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
                $1[i][j] = new griddb::Row(length);
                if ($1[i][j] == NULL) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                    free((void *) typeArr);
                    delete containerInfoTmp;
                    SWIG_fail;
                }
                griddb::Field *tmpField = $1[i][j]->get_field_ptr();
                int k;
                for (k = 0; k < length; k++) {
                    if (!(convertObjectToFieldWithType(tmpField[k], PyList_GetItem(rowTmp, k), typeArr[k]))) {
                        char gsType[200];
                        sprintf(gsType, "Invalid value for column %d, type should be : %d", k, typeArr[k]);
                        PyErr_SetString(PyExc_ValueError, gsType);
                        delete containerInfoTmp;
                        free((void *) typeArr);
                        SWIG_fail;
                    }
                }
                j++;
            }
            free((void *)typeArr);
            delete containerInfoTmp;
            i++;
        }

    }
}

%typemap(doc, name = "container_entry") (griddb::Row*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) "dict{string name : list[list[object]] row_list} container_entry";

%typemap(freearg) (griddb::Row*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) {
    if ($4) {
        for (int i = 0; i < $4; i++) {
            for (int j = 0; j < $2[i]; j++) {
                if ($1[i] && $1[i][j]) {
                    delete($1[i][j]);
                }
            }
            if ($1[i]) {
                free((void*) $1[i]);
            }
        }
        free((void*) $1);
        free((void*) $2);
        free((void*) $3);
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
    for (int i = 0; i < *$4; i++) {
        PyObject* key = convertStrToObj((*$3)[i]);
        PyObject* list = PyList_New((*$2)[i]);
        for (int j = 0; j < (*$2)[i]; j++) {
            griddb::Row* rowPtr = $1->at(separateCount);
            PyObject *outList = PyList_New(rowPtr->get_count());
            if (outList == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                SWIG_fail;
            }
            for (int k = 0; k < rowPtr->get_count(); k++) {
                PyList_SetItem(outList, k, convertFieldToObject(rowPtr->get_field_ptr()[k], arg1->timestamp_output_with_float));
            }
            PyList_SetItem(list, j, outList);
            separateCount += 1;
        }

        //Add entry to map
        PyDict_SetItem(dict, key, list);
        Py_DECREF(key);
        Py_DECREF(list);
    }

    $result = dict;
}

%typemap(freearg) (std::vector<griddb::Row*> *listRow, size_t **listRowContainerCount,
        char*** listContainerName, size_t* containerCount) {
    int separateCount = 0;
    if (*$4) {
        for (int i = 0; i < *$4; i++) {
            for (int j = 0; j < (*$2)[i]; j++) {
                griddb::Row* rowPtr = $1->at(separateCount);
                delete(rowPtr);
                separateCount += 1;
            }
            free((void*) (*$3)[i]);
        }
        $1->clear();
        free((void*) *$2);
        free((void*) *$3);
    }
}

/**
 * Typemap for QueryAnalysisEntry.get()
 */
%typemap(in, numinputs = 0) (GSQueryAnalysisEntry* queryAnalysis) (GSQueryAnalysisEntry queryAnalysis1) {
    $1 = (GSQueryAnalysisEntry*) malloc(sizeof(GSQueryAnalysisEntry));
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
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
    if ($1) {
        if ($1->statement) {
            free((void*) $1->statement);
        }
        if ($1->type) {
            free((void*) $1->type);
        }
        if ($1->value) {
            free((void*) $1->value);
        }
        if ($1->valueType) {
            free((void*) $1->valueType);
        }
        free((void*) $1);
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

%#if PY_MAJOR_VERSION >= 3
    void __next__(GSRowSetType* type, Row* row, bool* hasNextRow,
            QueryAnalysisEntry** queryAnalysis, AggregationResult** aggResult){
        return $self->next(type, row, hasNextRow, queryAnalysis, aggResult);
    }
%#endif
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
        for (int i = 0; i < *$2; i++) {
            PyList_SetItem($result, i, convertStrToObj((*$1)[i]));
        }
    }
    return $result;
}

%typemap(freearg) (char*** listName, int* num) {
    if (*$2){
        for (int i = 0; i < *$2; i++) {
            free((*$1)[i]);
        }
        free((void *) *$1);
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
%newobject griddb::Store::partition_info;
%attribute(griddb::Store, griddb::PartitionController*, partition_info, partition_info);
//Read and write attribute ContainerInfo::name
%attribute(griddb::ContainerInfo, GSChar*, name, get_name, set_name);
//Read and write attribute ContainerInfo::type
%attribute(griddb::ContainerInfo, int, type, get_type, set_type);
//Read and write attribute ContainerInfo::rowKeyAssign
%attribute(griddb::ContainerInfo, bool, row_key, get_row_key_assigned, set_row_key_assigned);
//Read and write attribute ContainerInfo::rowKeyAssign
%attribute(griddb::ContainerInfo, griddb::ExpirationInfo, expiration, get_expiration_info, set_expiration_info);
//Read only attribute ExpirationInfo::time
%attribute(griddb::ExpirationInfo, int, time, get_time, set_time);
//Read and write attribute ExpirationInfo::unit
%attribute(griddb::ExpirationInfo, GSTimeUnit, unit, get_time_unit, set_time_unit);
//Read and write attribute ExpirationInfo::divisionCount
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
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }

    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    if ($2 > 0) {
        int columnCount = arg1->getColumnCount();
        GSType type;

        $1 = (griddb::Row**) malloc($2 * sizeof(griddb::Row*));
        if ($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        int length;
        for (int i = 0; i < $2; i++) {
            PyObject* rowTmp = PyList_GetItem($input, i);
            length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
            if (length != columnCount) {
                $2 = i;
                %variable_fail(1, "Row", "num row is different with container info");
            }
            $1[i] = new griddb::Row(length);
            if ($1[i] == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                SWIG_fail;
            }
            GSType* typeList = arg1->getGSTypeList();
            griddb::Field *tmpField = $1[i]->get_field_ptr();
            for (int k = 0; k < length; k++) {
                type = typeList[k];
                PyObject* fieldObj = PyList_GetItem(rowTmp, k);
                if (!(convertObjectToFieldWithType(tmpField[k], fieldObj, type))) {
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

%typemap(doc, name = "row_list") (griddb::Row** listRowdata, int rowCount) "list[list[object]]";

//attribute ContainerInfo::column_info_list
%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (ColumnInfoList columnInfoList) (int* alloc){

    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int res;
    char* v = 0;
    bool vbool;
    alloc = (int*) malloc(sizeof(int));
    if (alloc == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    memset(alloc, 0, sizeof(int));
    size_t size = 0;
    size = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1.columnInfo = NULL;
    $1.size = size;
    size_t stringSize = 0;
    if (size) {
        $1.columnInfo = (GSColumnInfo*) malloc(size * sizeof(GSColumnInfo));
        if ($1.columnInfo == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation for set column_info_list is error");
            SWIG_fail;
        }
        PyObject* columInfoList;
        int option;
        for (int i = 0; i < size; i++) {
            columInfoList = PyList_GetItem($input, i);
            if (!PyList_Check(columInfoList)) {
                PyErr_SetString(PyExc_ValueError, "Expected a List");
                free((void*) $1.columnInfo);
                SWIG_fail;
            }
            size_t sizeColumn = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(columInfoList)));
%#if GS_COMPATIBILITY_SUPPORT_3_5
            if (sizeColumn < 2) {
                PyErr_SetString(PyExc_ValueError, "Expect column info has 3 elements");
                free((void*) $1.columnInfo);
                SWIG_fail;
            }

            res = SWIG_AsCharPtrAndSize(PyList_GetItem(columInfoList, 0), &v, &stringSize, alloc);
            if (!SWIG_IsOK(res)) {
                free((void*) $1.columnInfo);
                free((void*) alloc);
                $1.columnInfo = NULL;
                return false;
            }
            $1.columnInfo[i].name = strdup(v);
            free((void*) v);
            $1.columnInfo[i].type = PyLong_AsLong(PyList_GetItem(columInfoList, 1));
            if (sizeColumn == 3) {
                option = PyInt_AsLong(PyList_GetItem(columInfoList, 2));
                $1.columnInfo[i].options = option;
                if (option != GS_TYPE_OPTION_NULLABLE && option != GS_TYPE_OPTION_NOT_NULL) {
                    PyErr_SetString(PyExc_ValueError, "Invalid value for column option");
                    SWIG_fail;
                }
            } else if (sizeColumn == 2) {
                $1.columnInfo[i].options = 0;
            }
%#else
            if (sizeColumn < 2) {
                PyErr_SetString(PyExc_ValueError,"Expect column info has 2 elements");
                free((void*) $1.columnInfo);
                $1.columnInfo = NULL;
                SWIG_fail;
            }
            res = SWIG_AsCharPtrAndSize(PyList_GetItem(columInfoList, 0), &v, &size, alloc);
            if (!SWIG_IsOK(res)) {
                free((void*) $1.columnInfo);
                $1.columnInfo = NULL;
                return false;
            }
            $1.columnInfo[i].name = strdup(v);
            free((void*) v);
            $1.columnInfo[i].type = PyLong_AsLong(PyList_GetItem(columInfoList, 1));
%#endif
        }
    }
}

%typemap(freearg) (ColumnInfoList columnInfoList) {
    size_t size = $1.size;

    for (int i = 0; i < size; i++) {
        if ($1.columnInfo[i].name) {
            %delete_array($1.columnInfo[i].name);
        }
    }
    if ($1.columnInfo) {
        free((void *) $1.columnInfo);
    }
    if (alloc$argnum) {
        free(alloc$argnum);
    }

}

%typemap(out, fragment="convertStrToObj") (ColumnInfoList) {
    ColumnInfoList data = $1;
    size_t size = data.size;
    $result = PyList_New(size);
    if ($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for column_info_list is error");
        SWIG_fail;
    }
    for (int i = 0; i < size; i++) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
        PyObject* info = 0;
        if ((data.columnInfo)[i].options !=0 ) {
            info = PyList_New(3);
            PyList_SetItem(info, 0, convertStrToObj((data.columnInfo)[i].name));
            PyList_SetItem(info, 1, PyInt_FromLong((data.columnInfo)[i].type));
            PyList_SetItem(info, 2, PyInt_FromLong((data.columnInfo)[i].options));
        } else {
            info = PyList_New(2);
            PyList_SetItem(info, 0, convertStrToObj((data.columnInfo)[i].name));
            PyList_SetItem(info, 1, PyInt_FromLong((data.columnInfo)[i].type));
        }
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
    if ($2 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    hasNextRowTmp = true;
    $3 = &hasNextRowTmp;
    $4 = &queryAnalysisTmp;
    $5 = &aggResultTmp;
}

%typemap(argout, fragment = "convertFieldToObject") (GSRowSetType* type, griddb::Row* row, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {

    PyObject *resultobj;
    PyObject *outList;
    std::shared_ptr< griddb::AggregationResult > *aggResult = NULL;
    std::shared_ptr< griddb::QueryAnalysisEntry > *queryAnalyResult = NULL;
    switch(*$1) {
        case (GS_ROW_SET_CONTAINER_ROWS):

            if (*$3 == false) {
                PyErr_SetNone(PyExc_StopIteration);
                $result= NULL;
            } else {
                outList = PyList_New($2->get_count());
                if (outList == NULL) {
                    if ($2) {
                        delete $2;
                    }
                    PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                    SWIG_fail;
                }
                for (int i = 0; i < $2->get_count(); i++) {
                    PyList_SetItem(outList, i, convertFieldToObject($2->get_field_ptr()[i], arg1->timestamp_output_with_float));
                }
                $result = outList;
            }
            break;
        case (GS_ROW_SET_AGGREGATION_RESULT):
            if (*$3 == false) {
                PyErr_SetNone(PyExc_StopIteration);
                $result= NULL;

            } else {
                aggResult = *$5 ? new std::shared_ptr<  griddb::AggregationResult >(*$5 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
                resultobj = SWIG_NewPointerObj(SWIG_as_voidptr(aggResult), SWIGTYPE_p_std__shared_ptrT_griddb__AggregationResult_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
                $result = resultobj;
            }
            break;
        default:
            queryAnalyResult = *$4 ? new std::shared_ptr<  griddb::QueryAnalysisEntry >(*$4 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
            resultobj = SWIG_NewPointerObj(SWIG_as_voidptr(queryAnalyResult), SWIGTYPE_p_std__shared_ptrT_griddb__QueryAnalysisEntry_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
            $result = resultobj;
            break;
    }
    if ($2) {
        delete $2;
    }
    return $result;
}

%typemap(freearg) (GSRowSetType* type, griddb::Row* row, bool* hasNextRow,
        griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {
    if ($2) {
        delete $2;
    }
}
