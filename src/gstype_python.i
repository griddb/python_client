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
#include <Field.h>
#include <ctime>
#include <datetime.h>
#include <limits>
%}
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

/**
 * Support clean output of SWIG_AsCharPtrAndSize after used
 */
%fragment("cleanString", "header") {
static void cleanString(const GSChar* string, int alloc){
    if (!string) {
        return;
    }

    if (string && alloc == SWIG_NEWOBJ) {
        delete [] string;
    }
}
}

/*
* fragment to support converting Field to PyObject support RowKeyPredicate, AggregationResult
*/


%fragment("convertFieldToObject", "header",
        fragment = "convertStrToObj", fragment = "convertTimestampToObject") {
static PyObject* convertFieldToObject(GSValue* value, GSType type, bool timestamp_to_float = true) {

    size_t size;
    const int8_t *byteArrVal;
    const int16_t *shortArrVal;
    const int32_t *intArrVal;
    const int64_t *longArrVal;
    const double *doubleArrVal;
    const float *floatArrVal;
    const GSChar *const *stringArrVal;
    const GSBool *boolArrVal;
    const GSTimestamp *timestampArrVal;
    PyObject* list;
    int i;

    switch (type) {
        case GS_TYPE_LONG:
            return PyLong_FromLong(value->asLong);
        case GS_TYPE_STRING:
            return convertStrToObj(value->asString);
%#if GS_COMPATIBILITY_SUPPORT_3_5
        case GS_TYPE_NULL:
            Py_RETURN_NONE;
%#endif
        case GS_TYPE_BLOB:
            return PyByteArray_FromStringAndSize((GSChar *)value->asBlob.data, value->asBlob.size);

        case GS_TYPE_BOOL:
            return PyBool_FromLong(value->asBool);
        case GS_TYPE_INTEGER:
            return PyInt_FromLong(value->asInteger);
        case GS_TYPE_FLOAT:
            return PyFloat_FromDouble(value->asFloat);
        case GS_TYPE_DOUBLE:
            return PyFloat_FromDouble(value->asDouble);
        case GS_TYPE_TIMESTAMP:
            return convertTimestampToObject(&value->asTimestamp, timestamp_to_float);
        case GS_TYPE_BYTE:
            return PyInt_FromLong(value->asByte);
        case GS_TYPE_SHORT:
            return PyInt_FromLong(value->asShort);
        case GS_TYPE_GEOMETRY:
            return convertStrToObj(value->asGeometry);
        case GS_TYPE_INTEGER_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asIntegerArray.size;
            intArrVal = value->asIntegerArray.elements;
%#else
            size = value->asArray.length;
            intArrVal = value->asArray.elements.asInteger;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyInt_FromLong(intArrVal[i]));
            }
            return list;
        case GS_TYPE_STRING_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asStringArray.size;
            stringArrVal = value->asStringArray.elements;
%#else
            size = value->asArray.length;
            stringArrVal = value->asArray.elements.asString;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, convertStrToObj(stringArrVal[i]));
            }
            return list;
        case GS_TYPE_BOOL_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asBoolArray.size;
            boolArrVal = value->value.asBoolArray.elements;
%#else
            size = value->asArray.length;
            boolArrVal = value->asArray.elements.asBool;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyBool_FromLong(boolArrVal[i]));
            }
            return list;
        case GS_TYPE_BYTE_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asByteArray.size;
            byteArrVal = value->asByteArray.elements;
%#else
            size = value->asArray.length;
            byteArrVal = value->asArray.elements.asByte;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyInt_FromLong(byteArrVal[i]));
            }
            return list;
        case GS_TYPE_SHORT_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asShortArray.size;
            shortArrVal = value->asShortArray.elements;
%#else
            size = value->asArray.length;
            shortArrVal = value->asArray.elements.asShort;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyInt_FromLong(shortArrVal[i]));
            }
            return list;
        case GS_TYPE_LONG_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asLongArray.size;
            longArrVal = value->asLongArray.elements;
%#else
            size = value->asArray.length;
            longArrVal = value->asArray.elements.asLong;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyLong_FromLong(longArrVal[i]));
            }
            return list;
        case GS_TYPE_FLOAT_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asFloatArray.size;
            floatArrVal = value->asFloatArray.elements;
%#else
            size = value->asArray.length;
            floatArrVal = value->asArray.elements.asFloat;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyFloat_FromDouble(static_cast<double>(floatArrVal[i])));
            }
            return list;
        case GS_TYPE_DOUBLE_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asDoubleArray.size;
            doubleArrVal = value->asDoubleArray.elements;
%#else
            size = value->asArray.length;
            doubleArrVal = value->asArray.elements.asDouble;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, PyFloat_FromDouble(doubleArrVal[i]));
            }
            return list;
        case GS_TYPE_TIMESTAMP_ARRAY:
%#if GS_COMPATIBILITY_VALUE_1_1_106
            size = value->asTimestampArray.size;
            timestampArrVal = value->asTimestampArray.elements;
%#else
            size = value->asArray.length;
            timestampArrVal = value->asArray.elements.asTimestamp;
%#endif
            list = PyList_New(size);
            for (i = 0; i < size; i++) {
                PyList_SetItem(list, i, convertTimestampToObject((GSTimestamp*)&(timestampArrVal[i]), timestamp_to_float));
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
%fragment("convertObjectToGSTimestamp", "header", fragment = "convertObjectToFloat"
        , fragment = "cleanString") {
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
            cleanString(v, alloc);
            return false;
        }
        // this is for convert python's string datetime (YYYY-MM-DDTHH:mm:ss:sssZ)
        // to griddb's string datetime (YYYY-MM-DDTHH:mm:ss.sssZ)
        v[19] = '.';
        //Date format is YYYY-MM-DDTHH:mm:ss.sssZ

        retConvertTimestamp = gsParseTime(v, timestamp);
        cleanString(v, alloc);

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
static bool convertObjectToBool(PyObject* value, GSBool* boolValPtr) {
    bool tmpBool;
    int checkConvert = 0;
    if (PyInt_Check(value)) {
        //input can be integer
        int intVal;
        checkConvert = SWIG_AsVal_int(value, &intVal);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        *boolValPtr = ((intVal != 0) ? GS_TRUE : GS_FALSE);
        return true;
    } else {
        //input is boolean
        checkConvert = SWIG_AsVal_bool(value, &tmpBool);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        *boolValPtr = ((tmpBool == true) ? GS_TRUE : GS_FALSE);
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
%fragment("convertObjectToBlob", "header", fragment = "checkPyObjIsStr", fragment = "cleanString") {
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
        //Ignore null character
        *size = *size - 1;
        if (blobData) {
            *data = (void*) strdup(blobData);
            cleanString(blobData, alloc);
        }
        return true;
    }
    return false;
}
}

%fragment("cleanStringArray", "header") {
static void cleanStringArray(GSChar** arrString, size_t size) {
    if (!arrString) {
        return;
    }

    for (int i = 0; i < size; i++) {
        if (arrString[i]) {
            free((void*)arrString[i]);
        }
    }

    free(arrString);
}
}

%fragment("convertObjectToStringArray", "header", 
        fragment = "checkPyObjIsStr", fragment = "cleanString",
        fragment = "cleanStringArray") {
static GSChar** convertObjectToStringArray(PyObject* value, size_t* size) {
    GSChar** arrString;
    size_t arraySize;
    int alloc = 0;
    char* v;

    if (!PyList_Check(value)) {
        return NULL;
    }
    arraySize = PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
    *size = (int)arraySize;
    arrString = (GSChar**)malloc(arraySize * sizeof(GSChar*));
    if (arrString == NULL) {
        return NULL;
    }
    
    memset(arrString, 0x0, arraySize * sizeof(GSChar*));
    for (int i = 0; i < arraySize; i++) {
        if (!checkPyObjIsStr(PyList_GetItem(value, i))) {
            cleanStringArray(arrString, arraySize);
            return NULL;
        }
        
        int res = SWIG_AsCharPtrAndSize(PyList_GetItem(value, i), &v, NULL, &alloc);
        if (!SWIG_IsOK(res)) {
            cleanStringArray(arrString, arraySize);
            return NULL;
        }

        if (v) {
             arrString[i] = strdup(v); 
             cleanString(v, alloc);
             if (!arrString[i]) {
                 cleanStringArray(arrString, arraySize);
                 return NULL;
             }
         } else {
             arrString[i] = NULL;
         }
    }

    return arrString;
}
}
/**
 * Support convert row key Field from PyObject* to C Object with specific type
 */
%fragment("convertToRowKeyFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize",
        fragment = "checkPyObjIsStr", fragment = "convertObjToStr", fragment = "convertObjectToDouble",
        fragment = "convertObjectToGSTimestamp", fragment = "SWIG_AsVal_bool",
        fragment = "convertObjectToBlob", fragment = "convertObjectToBool",
        fragment = "convertObjectToFloat", fragment = "convertObjectToStringArray",
        fragment = "cleanString") {
    static bool convertToRowKeyFieldWithType(griddb::Field &field, PyObject* value, GSType type) {
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
        GSChar** arrString = NULL;
        PyObject* objectsRepresentation;
        int arraySize, i;
        void* arrayPtr;
        int tmpInt;
        long double tmpLongDouble;
        double tmpDouble; //support convert to double, double array
        float tmpFloat; //support convert to float, float array
        bool inBorderVal = false;
        bool inRange = false;
        GSBool* tmpPtr;
        switch(type) {
            case (GS_TYPE_STRING):
                if (!checkPyObjIsStr(value)) {
                    return false;
                }
                res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);

                if (!SWIG_IsOK(res)) {
                    return false;
                }

                if (v) {
                    field.value.asString = strdup(v);
                    if (!field.value.asString) {
                        return false;
                    }
                }

                cleanString(v, alloc);
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
                break;
            case (GS_TYPE_TIMESTAMP):
                return convertObjectToGSTimestamp(value, &field.value.asTimestamp);
                break;
            default:
                //Not support for now
                return false;
                break;
        }
        return true;
    }
}

%fragment("convertToFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize",
        fragment = "checkPyObjIsStr", fragment = "convertObjToStr", fragment = "convertObjectToDouble",
        fragment = "convertObjectToGSTimestamp", fragment = "SWIG_AsVal_bool",
        fragment = "convertObjectToBlob", fragment = "convertObjectToBool",
        fragment = "convertObjectToFloat", fragment = "convertObjectToStringArray",
        fragment = "cleanString") {
    static bool convertToFieldWithType(GSRow *row, int column, PyObject* value, GSType type) {
        int8_t byteVal;
        int16_t shortVal;
        int32_t intVal;
        int64_t longVal;
        float floatVal;
        double doubleVal;
        GSChar* stringVal;
        GSBlob blobValTmp;
        GSBlob *blobVal = &blobValTmp;
        GSBool boolVal;
        GSTimestamp timestampVal;
        GSChar *geometryVal;

        size_t size;
        int8_t *byteArrVal;
        int16_t *shortArrVal;
        int32_t *intArrVal;
        int64_t *longArrVal;
        double *doubleArrVal;
        float *floatArrVal;
        const GSChar *const *stringArrVal;
        GSBool *boolArrVal;
        GSTimestamp *timestampArrVal;

        int tmpInt; //support convert 
        double tmpDouble; //support convert to double, double array
        float tmpFloat; //support convert to float, float array
        int res;
        char* v = 0;
        bool vbool;
        int alloc;
        int i;
        GSResult ret;

        if (value == Py_None) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
            ret = gsSetRowFieldNull(row, column); 
            return (ret == GS_RESULT_OK);
%#else
        //Not support NULL
        return false;
%#endif
        }

        int checkConvert = 0;
        switch(type) {
            case (GS_TYPE_STRING):
                if (!checkPyObjIsStr(value)) {
                    return false;
                }
                res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);
                if (!SWIG_IsOK(res)) {
                    return false;
                }
                stringVal = v;
                ret = gsSetRowFieldByString(row, column, stringVal);
                cleanString(stringVal, alloc);
                break;
            case (GS_TYPE_LONG):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_long(value, &longVal);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                ret = gsSetRowFieldByLong(row, column, longVal);
                break;
            case (GS_TYPE_BOOL):
                vbool = convertObjectToBool(value, &boolVal);
                if (!vbool) {
                    return false;
                }
                ret = gsSetRowFieldByBool(row, column, boolVal);
                break;
            case (GS_TYPE_BYTE):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_int(value, (int*)&intVal);
                if (!SWIG_IsOK(checkConvert) ||
                        intVal < std::numeric_limits<int8_t>::min() ||
                        intVal > std::numeric_limits<int8_t>::max()) {
                    return false;
                }
                byteVal = intVal;
                ret = gsSetRowFieldByByte(row, column, byteVal);
                break;

            case (GS_TYPE_SHORT):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_int(value, (int*)&intVal);
                if (!SWIG_IsOK(checkConvert) ||
                        intVal < std::numeric_limits<int16_t>::min() ||
                        intVal > std::numeric_limits<int16_t>::max()) {
                    return false;
                }
                shortVal = intVal;
                ret = gsSetRowFieldByShort(row, column, shortVal);
                break;

            case (GS_TYPE_INTEGER):
                if (PyBool_Check(value)) {
                    return false;
                }
                checkConvert = SWIG_AsVal_int(value, &intVal);
                if (!SWIG_IsOK(checkConvert)) {
                    return false;
                }
                ret = gsSetRowFieldByInteger(row, column, intVal);
                break;
            case (GS_TYPE_FLOAT):
                vbool = convertObjectToFloat(value, &floatVal);
                if (!vbool) {
                    return false;
                }
                ret = gsSetRowFieldByFloat(row, column, floatVal);
                break;
            case (GS_TYPE_DOUBLE):
                vbool = convertObjectToDouble(value, &doubleVal);
                if (!vbool) {
                    return false;
                }
                ret = gsSetRowFieldByDouble(row, column, doubleVal);
                break;
            case (GS_TYPE_TIMESTAMP):
                vbool = convertObjectToGSTimestamp(value, &timestampVal);
                if (!vbool) {
                    return false;
                }
                ret = gsSetRowFieldByTimestamp(row, column, timestampVal);
                break;
            case (GS_TYPE_BLOB):
                vbool = convertObjectToBlob(value, &blobVal->size, (void**) &blobVal->data);
                if (!vbool) {
                    return false;
                }
                ret = gsSetRowFieldByBlob(row, column, (const GSBlob *)blobVal);
                if (blobVal->data) {
                    free((void*)blobVal->data);
                }
                break;
            case (GS_TYPE_STRING_ARRAY):
                stringArrVal = convertObjectToStringArray(value, &size);
                if (!stringArrVal) {
                    return false;
                }
                ret = gsSetRowFieldByStringArray(row, column, stringArrVal, size);
                if (stringArrVal) {
                    for (i = 0; i < size; i++) {
                        if (stringArrVal[i]) {
                            free(const_cast<GSChar*> (stringArrVal[i]));
                        }
                    }
                    free(const_cast<GSChar**> (stringArrVal));
                }
                break;
                
            case (GS_TYPE_GEOMETRY):
                if (!checkPyObjIsStr(value)) {
                    return false;
                }
                res = SWIG_AsCharPtrAndSize(value, &geometryVal, &size, &alloc);

                if (!SWIG_IsOK(res)) {
                    return false;
                }

                ret = gsSetRowFieldByGeometry(row, column, geometryVal);
                cleanString(geometryVal, alloc);
                break;
            case (GS_TYPE_INTEGER_ARRAY):
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                intArrVal = (int32_t *) malloc(size * sizeof(int32_t));
                if (intArrVal == NULL) {
                    return false;
                }
                for (i = 0; i < size; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &intArrVal[i]);
                    if (!SWIG_IsOK(checkConvert) || vbool) {
                        free((void*)intArrVal);
                        intArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByIntegerArray(row, column, (const int32_t *) intArrVal, size);
                free ((void*) intArrVal);
                break;
            case GS_TYPE_BOOL_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                boolArrVal = (GSBool *) malloc(size * sizeof(GSBool));
                if (boolArrVal == NULL) {
                    return false;
                }
                for (i = 0; i < size; i++) {
                    vbool = convertObjectToBool(PyList_GetItem(value, i), &boolArrVal[i]);
                    if (!vbool) {
                        free((void*)boolArrVal);
                        boolArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByBoolArray(row, column, (const GSBool *)boolArrVal, size);
                free ((void*) boolArrVal);
                break;
            case GS_TYPE_BYTE_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                byteArrVal = (int8_t *) malloc(size * sizeof(int8_t));
                if (byteArrVal == NULL) {
                    return false;
                }

                for (i = 0; i < size; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &tmpInt);
                    *(((int8_t*)byteArrVal + i)) = (int8_t)tmpInt;
                     if (vbool || !SWIG_IsOK(checkConvert) ||
                        tmpInt < std::numeric_limits<int8_t>::min() ||
                        tmpInt > std::numeric_limits<int8_t>::max()) {
                         free((void*)byteArrVal);
                         byteArrVal = NULL;
                         return false;
                    }
                }
                ret = gsSetRowFieldByByteArray(row, column, (const int8_t *)byteArrVal, size);
                free ((void*) byteArrVal);
                break;
            case GS_TYPE_SHORT_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                shortArrVal = (int16_t *) malloc(size * sizeof(int16_t));
                if (shortArrVal == NULL) {
                    return false;
                }

                for (i = 0; i < size; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &tmpInt);
                    *(((int16_t*)shortArrVal + i)) = (int16_t)tmpInt;
                    if (vbool || !SWIG_IsOK(checkConvert) ||
                        tmpInt < std::numeric_limits<int16_t>::min() ||
                        tmpInt > std::numeric_limits<int16_t>::max()) {
                            free((void*)shortArrVal);
                            shortArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByShortArray(row, column, (const int16_t *)shortArrVal, size);
                free ((void*) shortArrVal);
                break;
            case GS_TYPE_LONG_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                longArrVal = (int64_t *) malloc(size * sizeof(int64_t));
                if (longArrVal == NULL) {
                    return false;
                }
                for (i = 0; i < size; i++) {
                    vbool = PyBool_Check(PyList_GetItem(value, i));
                    checkConvert = SWIG_AsVal_long(PyList_GetItem(value, i), ((int64_t *)longArrVal + i));
                    if (!SWIG_IsOK(checkConvert) || vbool) {
                        free((void*)longArrVal);
                        longArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByLongArray(row, column, (const int64_t *)longArrVal, size);
                free ((void*) longArrVal);
                break;
            case GS_TYPE_FLOAT_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                floatArrVal = (float *) malloc(size * sizeof(float));
                if (floatArrVal == NULL) {
                    return false;
                }
                for (i = 0; i < size; i++) {
                    vbool = convertObjectToFloat(PyList_GetItem(value, i), &floatArrVal[i]);
                    if (!vbool) {
                        free((void*)floatArrVal);
                        floatArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByFloatArray(row, column, (const float *) floatArrVal, size);
                free ((void*) floatArrVal);
                break;
            case GS_TYPE_DOUBLE_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                doubleArrVal = (double *) malloc(size * sizeof(double));
                if (doubleArrVal == NULL) {
                    return false;
                }
                for (i = 0; i < size; i++) {
                    vbool = convertObjectToDouble(PyList_GetItem(value, i), &tmpDouble);
                    *((double *)doubleArrVal + i) = tmpDouble;
                    if (!vbool){
                        free((void*)doubleArrVal);
                        doubleArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByDoubleArray(row, column, (const double *)doubleArrVal, size);
                free ((void*) doubleArrVal);
                break;
            case GS_TYPE_TIMESTAMP_ARRAY:
                if (!PyList_Check(value)) {
                    return false;
                }
                size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
                timestampArrVal = (GSTimestamp *) malloc(size * sizeof(GSTimestamp));
                if (timestampArrVal == NULL) {
                    return false;
                }
                bool checkRet;
                for (i = 0; i < size; i++) {
                    checkRet = convertObjectToGSTimestamp(PyList_GetItem(value, i), ((GSTimestamp *)timestampArrVal + i));
                    if (!checkRet) {
                        free((void*)timestampArrVal);
                        timestampArrVal = NULL;
                        return false;
                    }
                }
                ret = gsSetRowFieldByTimestampArray(row, column, (const GSTimestamp *)timestampArrVal, size);
                free ((void*) timestampArrVal);
                break;
            default:
                //Not support for now
                return false;
                break;
        }
        return (ret == GS_RESULT_OK);
    }
}

/**
* Typemaps for put_container() function
*/
%typemap(in, fragment = "SWIG_AsCharPtrAndSize", fragment = "cleanString") 
        (const GSColumnInfo* props, int propsCount)
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
            if (v) {
                $1[i].name = strdup(v);
                cleanString(v, alloc[i]);
                if (!$1[i].name) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                    SWIG_fail;
                }
            } else {
                $1[i].name = NULL;
            }
            if (!PyInt_Check(PyList_GetItem(list, 1))) {
                PyErr_SetString(PyExc_ValueError, "Expected an Integer as column type");
                SWIG_fail;
            }

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

%typemap(freearg, fragment = "cleanString") (const GSColumnInfo* props, int propsCount) (int i) {
    if ($1) {
        for (int i = 0; i < $2; i++) {
            cleanString($1[i].name, alloc$argnum[i]);
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

%typemap(freearg, fragment = "cleanString") (const GSPropertyEntry* props, int propsCount) (int i = 0, int j = 0) {
    if ($1) {
        for (int i = 0; i < $2; i++) {
            cleanString($1[i].name, alloc$argnum[j]);
            cleanString($1[i].value, alloc$argnum[j + 1]);
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

%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount) (PyObject* key, PyObject* val, std::shared_ptr<griddb::RowKeyPredicate> pPredicate, GSRowKeyPredicateEntry* pList = NULL, void *vpredicate, Py_ssize_t si, int i, int res = 0, size_t size = 0, int* alloc = 0, char* v = 0) {
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

%typemap(freearg, fragment = "cleanString") (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount) (int i) {
    if ($1 && *$1) {
        for (int i = 0; i < $2; i++) {
            cleanString((*$1)[i].containerName, alloc$argnum[i]);
        }
    }

    if (pList$argnum) {
        free(pList$argnum);
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
    $result = convertFieldToObject(&($1->value), $1->type, arg1->timestamp_output_with_float);
}

/**
* Typemaps for update() function
*/
%typemap(in, fragment="convertToFieldWithType") (GSRow* row) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    if (leng != arg1->getColumnCount()) {
        %variable_fail(1, "Row", "num row is different with container info");
    }
    GSRow *tmpRow = arg1->getGSRowPtr();
    int colNum = arg1->getColumnCount();
    GSType* typeList = arg1->getGSTypeList();
    for(int i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if(!(convertToFieldWithType(tmpRow, i, PyList_GetItem($input, i), type))) {
            char gsType[200];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }
}

%typemap(freearg) (GSRow* row) {
}

/**
* Typemaps for put_row() function
*/
%typemap(in, fragment="convertToFieldWithType") (GSRow *rowContainer) {
    $1 = NULL;
    if(!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));

    if (leng != arg1->getColumnCount()) {
        %variable_fail(1, "Row", "num row is different with container info");
    }

    GSRow* row = arg1->getGSRowPtr();
    GSType* typeList = arg1->getGSTypeList();
    for(int i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if(!(convertToFieldWithType(row, i, PyList_GetItem($input, i), type))) {
            char gsType[60];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }
}

%typemap(freearg) (GSRow *rowContainer) {
}

%typemap(doc, name = "row") (GSRow *rowContainer) "list[object]";

/*
* typemap for get_row
*/

%typemap(in, fragment = "convertToRowKeyFieldWithType") (griddb::Field* keyFields)(griddb::Field field) {
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
        if (!convertToRowKeyFieldWithType(*$1, $input, type)) {
            %variable_fail(1, "String", "can not convert to row field");
        }
    }
}

%typemap(doc, name = "key") (griddb::Field* keyFields) "object";

%typemap(in, numinputs = 0) (GSRow *rowdata) {
    $1 = NULL;
}

%typemap(argout, fragment = "convertFieldToObject") (GSRow *rowdata) {
    GSRow* row = arg1->getGSRowPtr();
    PyObject *outList = PyList_New(arg1->getColumnCount());
    if (outList == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }

    GSValue mValue;
    GSType mType;
    GSResult ret;
    for (int i = 0; i < arg1->getColumnCount(); i++) {
        ret = gsGetRowFieldGeneral(row, i, &mValue, &mType);
        if (ret != GS_RESULT_OK) {
            char errorMsg[60];
            sprintf(errorMsg, "Can't get data for field %d", i);
            PyErr_SetString(PyExc_ValueError, errorMsg);
        }
        PyList_SetItem(outList, i, convertFieldToObject(&mValue, mType, arg1->timestamp_output_with_float));
    }
    $result = outList;
}

/**
 * Create typemap for RowKeyPredicate.set_range
 */
%typemap(in, fragment= "convertToRowKeyFieldWithType") (griddb::Field* startKey)(griddb::Field field) {
    $1 = &field;
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    GSType type = arg1->get_key_type();
    if (!(convertToRowKeyFieldWithType(*$1, $input, type))) {
        %variable_fail(1, "String", "can not create row based on input");
    }
}

%typemap(doc, name = "start") (griddb::Field* startKey) "object start";

%typemap(in, fragment= "convertToRowKeyFieldWithType") (griddb::Field* finishKey)(griddb::Field field) {
    $1 = &field;
    if ($1 == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }

    GSType type = arg1->get_key_type();
    if (!(convertToRowKeyFieldWithType(*$1, $input, type))) {
        %variable_fail(1, "String", "can not create row based on input");
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

%typemap(argout, fragment="convertFieldToObject") (GSValue* startField, griddb::Field* finishField) {
    int length = 2;
    $result = PyList_New(2);
    if ($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    PyList_SetItem($result, 0, convertFieldToObject(&($1->value), $1->type, arg1->timestamp_output_with_float));
    PyList_SetItem($result, 1, convertFieldToObject(&($2->value), $1->type, arg1->timestamp_output_with_float));
}

/**
 * Typemap for RowKeyPredicate.set_distinct_keys
 */
%typemap(in, fragment="convertToRowKeyFieldWithType") (const griddb::Field *keys, size_t keyCount) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        return NULL;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        $1 = new griddb::Field[$2];
        if ($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        GSType type = arg1->get_key_type();
        for (int i = 0; i< $2; i++) {
            if (!(convertToRowKeyFieldWithType($1[i], PyList_GetItem($input, i), type))) {
                %variable_fail(1, "String", "can not create row based on input");
            }
        }
    }
}

%typemap(freearg) (const griddb::Field *keys, size_t keyCount) {
    if ($1) {
        delete [] $1;
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
        PyObject *o = convertFieldToObject(&keyList[num].value, keyList[num].type, arg1->timestamp_output_with_float);
        PyList_SetItem($result, num, o);
    }
}

%typemap(freearg) (griddb::Field **keys, size_t* keyCount) {
    if ($1) {
        delete [] (*$1);
    }
}

/**
 * Typemaps for Store.multi_put
 */
%typemap(in, fragment="convertToFieldWithType", fragment="convertObjToStr") (GSRow*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) () {
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $1 = NULL;
    $2 = NULL;
    $3 = NULL;
    $4 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    griddb::Container* tmpContainer;
    if ($4 > 0) {
        $1 = new GSRow**[$4];

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
        for (j = 0; j < $4; j++) {
            $1[j] = NULL;
        }
        //End init
        Py_ssize_t si = 0;
        PyObject* containerName;
        PyObject* listRowContainer;
        griddb::ContainerInfo* containerInfoTmp;
        ColumnInfoList infoListTmp;
        while (PyDict_Next($input, &si, &containerName, &listRowContainer)) {
            int numRowOfContainer = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(listRowContainer)));
            if (numRowOfContainer < 0) {
                PyErr_SetString(PyExc_ValueError, "Num rows of container is invalid.");
                SWIG_fail;
            }
            $1[i] = new GSRow* [numRowOfContainer];
            if ($1[i] == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                SWIG_fail;
            }
            //Init default null row
            for (j = 0; j < numRowOfContainer; j++) {
                $1[i][j] = NULL;
            }
            //End init
            $2[i] = numRowOfContainer;
            $3[i] = convertObjToStr(containerName);
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
            tmpContainer = arg1->get_container($3[i]);
            GSResult ret;
            for (j = 0; j < numRowOfContainer; j++) {
                PyObject* rowTmp = PyList_GetItem(listRowContainer, j);
                if (!PyList_Check(rowTmp)) {
                    PyErr_SetString(PyExc_ValueError, "Expected a List");
                    free((void *) typeArr);
                    delete containerInfoTmp;
                    SWIG_fail;
                }
                length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
                ret = gsCreateRowByContainer(tmpContainer->getGSContainerPtr(), &$1[i][j]);
                if ($1[i][j] == NULL || ret != GS_RESULT_OK) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                    free((void *) typeArr);
                    delete containerInfoTmp;
                    SWIG_fail;
                }
                for (int k = 0; k < length; k++) {
                    if (!(convertToFieldWithType($1[i][j], k, PyList_GetItem(rowTmp, k), typeArr[k]))) {
                        char gsType[200];
                        sprintf(gsType, "Invalid value for column %d, type should be : %d", k, typeArr[k]);
                        PyErr_SetString(PyExc_ValueError, gsType);
                        delete containerInfoTmp;
                        free((void *) typeArr);
                        SWIG_fail;
                    }
                }
            }
            free((void *)typeArr);
            delete containerInfoTmp;
            i++;
        }

    }
}

%typemap(doc, name = "container_entry") (GSRow*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) "dict{string name : list[list[object]] row_list} container_entry";

%typemap(freearg) (GSRow*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) {
    for(int i = 0; i < $4; i++) {
        if($1[i]) {
            for(int j = 0; j < $2[i]; j++) {
                gsCloseRow(&$1[i][j]);
            }
            delete $1[i];
        }
    }
    if($1) delete $1;
    if($2) delete $2;
    if($3) delete $3;
}

/**
 * Typemaps output for Store.multi_get() function
 */
%typemap(in, numinputs = 0) (GSContainerRowEntry **entryList, size_t* containerCount, int **colNumList) 
        (GSContainerRowEntry *tmpEntryList, size_t tmpContainerCount, int *tmpcolNumList) {
    $1 = &tmpEntryList;
    $2 = &tmpContainerCount;
    $3 = &tmpcolNumList;
}

%typemap(argout, numinputs = 0, fragment="convertStrToObj", fragment="convertFieldToObject") (GSContainerRowEntry **entryList, size_t* containerCount, int **colNumList) () {
    PyObject* dict = PyDict_New();
    griddb::Container *tmpContainer;
    GSRow* row;
    GSValue mValue;
    GSType mType;
    GSResult ret;
    for (int i = 0; i < *$2; i++) {
        PyObject* key = convertStrToObj((*$1)[i].containerName);
        PyObject* list = PyList_New((*$1)[i].rowCount);
        for (int j = 0; j < (*$1)[i].rowCount; j++) {
            row = (GSRow*)(*$1)[i].rowList[j];
            PyObject *outList = PyList_New((*$3)[i]);
            if (outList == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                SWIG_fail;
            }
            for (int k = 0; k < (*$3)[i]; k++) {
                ret = gsGetRowFieldGeneral(row, k, &mValue, &mType);
                if (ret != GS_RESULT_OK) {
                    char errorMsg[60];
                    sprintf(errorMsg, "Can't get data for field %d", i);
                    PyErr_SetString(PyExc_ValueError, errorMsg);
                }
                PyList_SetItem(outList, k, convertFieldToObject(&mValue, mType, arg1->timestamp_output_with_float));
            }
            PyList_SetItem(list, j, outList);
        }

        //Add entry to map
        PyDict_SetItem(dict, key, list);
        Py_DECREF(key);
        Py_DECREF(list);
    }
    delete (*$3);
    $result = dict;
}

%typemap(freearg) (GSContainerRowEntry **entryList, size_t* containerCount, int **colNumList) {
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
    void __next__(GSRowSetType* type, bool* hasNextRow,
            QueryAnalysisEntry** queryAnalysis, AggregationResult** aggResult){
        return $self->next(type, hasNextRow, queryAnalysis, aggResult);
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
%typemap(in, fragment = "convertToFieldWithType") (GSRow** listRowdata, int rowCount) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }

    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    GSResult ret;
    if ($2 > 0) {
        GSContainer *mContainer = arg1->getGSContainerPtr();
        int columnCount = arg1->getColumnCount();
        GSType type;

        GSType* typeList = arg1->getGSTypeList();

        $1 = new GSRow*[$2];
        if ($1 == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            free((void*) typeList);
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
            ret = gsCreateRowByContainer(mContainer, &$1[i]);
            if (ret != GS_RESULT_OK) {
                PyErr_SetString(PyExc_ValueError, "Can't create GSRow");
                SWIG_fail;
            }
            for (int k = 0; k < length; k++) {
                type = typeList[k];
                PyObject* fieldObj = PyList_GetItem(rowTmp, k);
                if (!(convertToFieldWithType($1[i], k, fieldObj, type))) {
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

%typemap(freearg) (GSRow** listRowdata, int rowCount) {
    if($1) {
        for (int rowNum = 0; rowNum < $2; rowNum++) {
            gsCloseRow(&$1[rowNum]);
        }
        delete $1;
    }
}

%typemap(doc, name = "row_list") (GSRow** listRowdata, int rowCount) "list[list[object]]";

//attribute ContainerInfo::column_info_list
%typemap(in, fragment = "SWIG_AsCharPtrAndSize", fragment = "cleanString") (ColumnInfoList columnInfoList) (int* alloc){

    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int res;
    char* v = 0;
    bool vbool;
    size_t size = 0;
    size = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    
    alloc = (int*) malloc(size * sizeof(int));
    if (alloc == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation error");
        SWIG_fail;
    }
    memset(alloc, 0, size * sizeof(int));

    $1.columnInfo = NULL;
    $1.size = size;
    size_t stringSize = 0;
    if (size) {
        $1.columnInfo = (GSColumnInfo*) malloc(size * sizeof(GSColumnInfo));
        if ($1.columnInfo == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation for set column_info_list is error");
            SWIG_fail;
        }
        memset($1.columnInfo, 0x0, size * sizeof(GSColumnInfo));

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
            if (sizeColumn < 2) {
                PyErr_SetString(PyExc_ValueError, "Expect column info has 3 elements");
                free((void*) $1.columnInfo);
                SWIG_fail;
            }

            res = SWIG_AsCharPtrAndSize(PyList_GetItem(columInfoList, 0), &v, &stringSize, &alloc[i]);
            if (!SWIG_IsOK(res)) {
                free((void*) $1.columnInfo);
                $1.columnInfo = NULL;
                PyErr_SetString(PyExc_ValueError, "Can't convert field to string");
                SWIG_fail;
            }
            if (v) {
                $1.columnInfo[i].name = strdup(v);
                cleanString(v, alloc[i]);
            }
            $1.columnInfo[i].type = PyLong_AsLong(PyList_GetItem(columInfoList, 1));
%#if GS_COMPATIBILITY_SUPPORT_3_5
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
%#endif
        }
    }
}

%typemap(freearg) (ColumnInfoList columnInfoList) {
    size_t size = $1.size;

    if (alloc$argnum) {
        for (int i = 0; i < size; i++) {
            if (alloc$argnum[i]) {
                %delete_array($1.columnInfo[i].name);
            }
        }
        free(alloc$argnum);
    }
    
    if ($1.columnInfo) {
        free((void *) $1.columnInfo);
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
%typemap(in, numinputs = 0) (GSRowSetType* type, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult)
    (GSRowSetType typeTmp, bool hasNextRowTmp,
            griddb::QueryAnalysisEntry* queryAnalysisTmp = NULL, griddb::AggregationResult* aggResultTmp = NULL) {
    $1 = &typeTmp;
    hasNextRowTmp = true;
    $2 = &hasNextRowTmp;
    $3 = &queryAnalysisTmp;
    $4 = &aggResultTmp;
}

%typemap(argout, fragment = "convertFieldToObject") (GSRowSetType* type, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {

    PyObject *resultobj;
    PyObject *outList;
    std::shared_ptr< griddb::AggregationResult > *aggResult = NULL;
    std::shared_ptr< griddb::QueryAnalysisEntry > *queryAnalyResult = NULL;
    GSValue mValue;
    GSType mType;
    GSResult ret;
    switch(*$1) {
        case (GS_ROW_SET_CONTAINER_ROWS):
            if (*$2 == false) {
                PyErr_SetNone(PyExc_StopIteration);
                $result= NULL;
            } else {
                GSRow* row = arg1->getGSRowPtr();
                PyObject *outList = PyList_New(arg1->getColumnCount());
                if (outList == NULL) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                    SWIG_fail;
                }
                for (int i = 0; i < arg1->getColumnCount(); i++) {
                    ret = gsGetRowFieldGeneral(row, i, &mValue, &mType);
                    if (ret != GS_RESULT_OK) {
                        char errorMsg[60];
                        sprintf(errorMsg, "Can't get data for field %d", i);
                        PyErr_SetString(PyExc_ValueError, errorMsg);
                    }
                    PyList_SetItem(outList, i, convertFieldToObject(&mValue, mType, arg1->timestamp_output_with_float));
                }
                $result = outList;
            }
            break;

        case (GS_ROW_SET_AGGREGATION_RESULT):
            if (*$2 == false) {
                PyErr_SetNone(PyExc_StopIteration);
                $result= NULL;
            } else {
                aggResult = *$4 ? new std::shared_ptr<  griddb::AggregationResult >(*$4 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
                resultobj = SWIG_NewPointerObj(SWIG_as_voidptr(aggResult), SWIGTYPE_p_std__shared_ptrT_griddb__AggregationResult_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
                $result = resultobj;
            }
            break;
        default:
            queryAnalyResult = *$3 ? new std::shared_ptr<  griddb::QueryAnalysisEntry >(*$3 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
            resultobj = SWIG_NewPointerObj(SWIG_as_voidptr(queryAnalyResult), SWIGTYPE_p_std__shared_ptrT_griddb__QueryAnalysisEntry_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
            $result = resultobj;
            break;
    }
    return $result;
}
