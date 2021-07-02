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
#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
#include <numpy/arrayobject.h>
#include <numpy/npy_math.h>
%}
%ignore griddb::AggregationResult::setOutputTimestamp;
%ignore griddb::Container::setOutputTimestamp;
%ignore griddb::ContainerInfo::ContainerInfo(GSContainerInfo* containerInfo);
%ignore griddb::RowSet::next_row;
%ignore griddb::RowSet::get_next_query_analysis;
%ignore griddb::RowSet::get_next_aggregation;
%ignore griddb::RowSet::setOutputTimestamp;
%ignore griddb::Store::setOutputTimestamp;
%ignore griddb::RowKeyPredicate::setOutputTimestamp;

%pythonbegin %{
from enum import IntEnum
import pandas
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

%#if GS_INTERNAL_DEFINITION_VISIBLE
%#if !GS_COMPATIBILITY_DEPRECATE_FETCH_OPTION_SIZE
    SIZE = (LIMIT + 1)
%#endif
%#endif
%#if GS_COMPATIBILITY_SUPPORT_4_0
    PARTIAL_EXECUTION = (LIMIT + 2)
%#endif
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
    NULL = -1

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
    return (char*) PyUnicode_AsUTF8(string);
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

/**
 * Support check PyObject* is long
 */
%fragment("checkPyObjIsLong", "header") {
bool checkPyObjIsLong(PyObject* obj) {
%#if PY_MAJOR_VERSION < 3
    return (PyLong_Check(obj) || PyInt_Check(obj)) && !PyBool_Check(obj);
%#else
    return PyLong_Check(obj) && !PyBool_Check(obj);
%#endif
}
}

%fragment("convertTimestampToObject", "header") {
static PyObject* convertTimestampToObject(GSTimestamp* timestamp, bool timestampToFloat = true) {
    // In C-API there is function PyDateTime_FromTimestamp convert from datetime to local datetime (not UTC).
    // But GridDB use UTC datetime => use the string output from gsFormatTime to convert to UTC datetime
    if (timestampToFloat) {
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
    int year, month, day, hour, minute, second, miliSecond, microSecond;
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
static PyObject* convertFieldToObject(GSValue* value, GSType type, bool timestampToFloat = true) {

    PyObject* list;
    int i;
    switch (type) {
        case GS_TYPE_LONG:
            return SWIG_From_dec(long long)(value->asLong);
        case GS_TYPE_STRING:
            return convertStrToObj(value->asString);
        case GS_TYPE_INTEGER:
            return PyInt_FromLong(value->asInteger);
        case GS_TYPE_DOUBLE:
            return PyFloat_FromDouble(value->asDouble);
        case GS_TYPE_TIMESTAMP:
            return convertTimestampToObject(&value->asTimestamp, timestampToFloat);
        default:
            Py_RETURN_NONE;
    }
}
}

/**
 * Support convert type from object to GSTimestamp: input in target language can be :
 * datetime object, string or float
 */
%fragment("convertObjectToGSTimestamp", "header", fragment = "convertObjectToFloat"
        , fragment = "cleanString", fragment = "checkPyObjIsLong") {
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

        // Input is datetime string: ex 1970-01-01T00:00:00.000Z
        res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);

        if (!SWIG_IsOK(res)) {
           return false;
        }
        retConvertTimestamp = gsParseTime(v, timestamp);
        cleanString(v, alloc);
        return (retConvertTimestamp == GS_TRUE);
    } else if (PyFloat_Check(value)) {
        // Input is python utc timestamp
        vbool = convertObjectToDouble(value, &utcTimestamp);
        if (!vbool) {
            return false;
        }
        *timestamp = utcTimestamp * 1000;
        if (utcTimestamp > UTC_TIMESTAMP_MAX) {
            return false;
        }
        return true;
    } else if (checkPyObjIsLong(value)) {
        int64_t tmp;
        SWIG_AsVal_dec(long long)(value, (long long *)&tmp);
        utcTimestamp = tmp;
        if (utcTimestamp == 0) { // int type for timestamp input is not correct except 0 value.
            *timestamp = 0;
            return true;
        } else {
            return false;
        }
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
    } else {
        //input is boolean
        checkConvert = SWIG_AsVal_bool(value, &tmpBool);
        if (!SWIG_IsOK(checkConvert)) {
            return false;
        }
        *boolValPtr = ((tmpBool == true) ? GS_TRUE : GS_FALSE);
    }
    return true;
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
        int64_t intVal;
        checkConvert = SWIG_AsVal_dec(long long)(value, (long long *)&intVal);
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
        int64_t intVal;
        checkConvert = SWIG_AsVal_dec(long long)(value, (long long *)&intVal);
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

         return (*floatValPtr < std::numeric_limits<float>::max() &&
                 *floatValPtr > -1 *std::numeric_limits<float>::max());
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
    int res;
    if (PyByteArray_Check(value)) {
        *size = PyByteArray_Size(value);
        try {
            blobData = new GSChar[*size]();
            memcpy(blobData, PyByteArray_AsString(value), *size);
            *data = (void*) blobData;
        } catch (bad_alloc& ba) {
            return false;
        }
        return true;
    } else if (checkPyObjIsStr(value)) {
        int alloc;
        res = SWIG_AsCharPtrAndSize(value, &blobData, size, &alloc);
        if (!SWIG_IsOK(res)) {
           return false;
        }
        try {
            griddb::Util::strdup((const GSChar** const)data, (const GSChar*)blobData);
            cleanString(blobData, alloc);
        } catch (bad_alloc& ba) {
            cleanString(blobData, alloc);
            return false;
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
            // Free memory for string after using griddb::Util::strdup()
            delete [] arrString[i];
        }
    }

    delete [] arrString;
}
}

%fragment("convertObjectToStringArray", "header", fragment = "checkPyObjIsStr",
        fragment = "cleanString", fragment = "cleanStringArray") {
static bool convertObjectToStringArray(PyObject* value, GSChar*** arrString, size_t* size) {
    size_t arraySize;
    int alloc = 0;
    char* v;

    if (!PyList_Check(value)) {
        return false;
    }
    arraySize = PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
    *size = (int)arraySize;
    try {
        *arrString = new GSChar*[arraySize]();
    } catch (bad_alloc& ba) {
        return false;
    }

    for (int i = 0; i < arraySize; i++) {
        if (!checkPyObjIsStr(PyList_GetItem(value, i))) {
            cleanStringArray(*arrString, arraySize);
            return false;
        }
        int res = SWIG_AsCharPtrAndSize(PyList_GetItem(value, i), &v, NULL, &alloc);
        if (!SWIG_IsOK(res)) {
            cleanStringArray(*arrString, arraySize);
            return false;
        }

        if (v) {
            try {
                griddb::Util::strdup((const GSChar** const)&((*arrString)[i]), v);
                cleanString(v, alloc);
            } catch (bad_alloc& ba) {
                cleanString(v, alloc);
                cleanStringArray(*arrString, arraySize);
                return false;
            }
         } else {
             (*arrString)[i] = NULL;
         }
    }

    return true;
}
}
/**
 * Support convert row key Field from PyObject* to C Object with specific type
 */
%fragment("convertToRowKeyFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize",
        fragment = "checkPyObjIsStr", fragment = "convertObjToStr", fragment = "convertObjectToDouble",
        fragment = "convertObjectToGSTimestamp", fragment = "cleanString") {
static bool convertToRowKeyFieldWithType(griddb::Field &field, PyObject* value, GSType type) {
    field.type = type;

    if (value == Py_None) {
        //Not support NULL
        return false;
    }

    int checkConvert = 0;
    switch (type) {
        case (GS_TYPE_STRING): {
            size_t size = 0;
            int res;
            char* v;
            int alloc;
            if (!checkPyObjIsStr(value)) {
                return false;
            }
            res = SWIG_AsCharPtrAndSize(value, &v, &size, &alloc);
            if (!SWIG_IsOK(res)) {
                return false;
            }

            if (v) {
                try {
                    griddb::Util::strdup((const GSChar** const)&field.value.asString, v);
                    cleanString(v, alloc);
                } catch (bad_alloc& ba) {
                    cleanString(v, alloc);
                    return false;
                }
            }
            break;
        }
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
            checkConvert = SWIG_AsVal_dec(long long)(value, (long long *)&field.value.asLong);
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
        fragment = "checkPyObjIsStr", fragment = "convertObjectToDouble",
        fragment = "convertObjectToGSTimestamp",
        fragment = "convertObjectToBlob", fragment = "convertObjectToBool",
        fragment = "convertObjectToFloat", fragment = "convertObjectToStringArray",
        fragment = "cleanString") {
static bool convertToFieldWithType(GSRow *row, int column, PyObject* value, GSType type) {
    int32_t intVal;
    size_t size;
    int tmpInt; //support convert to byte array, short array
    int res;
    bool vbool;
    int alloc;
    int i;
    GSResult ret;

    if (value == Py_None) {
        ret = gsSetRowFieldNull(row, column);
        return (ret == GS_RESULT_OK);
    }

    int checkConvert = 0;
    switch (type) {
        case GS_TYPE_STRING: {
            GSChar* stringVal;
            if (!checkPyObjIsStr(value)) {
                return false;
            }
            res = SWIG_AsCharPtrAndSize(value, &stringVal, &size, &alloc);
            if (!SWIG_IsOK(res)) {
                return false;
            }
            ret = gsSetRowFieldByString(row, column, stringVal);
            cleanString(stringVal, alloc);
            break;
        }
        case GS_TYPE_LONG: {
            int64_t longVal;
            if (PyBool_Check(value)) {
                return false;
            }
            checkConvert = SWIG_AsVal_dec(long long)(value, (long long *)&longVal);
            if (!SWIG_IsOK(checkConvert)) {
                return false;
            }
            ret = gsSetRowFieldByLong(row, column, longVal);
            break;
        }
        case GS_TYPE_BOOL: {
            GSBool boolVal;
            vbool = convertObjectToBool(value, &boolVal);
            if (!vbool) {
                return false;
            }
            ret = gsSetRowFieldByBool(row, column, boolVal);
            break;
        }
        case GS_TYPE_BYTE: {
            int8_t byteVal;
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
        }
        case GS_TYPE_SHORT: {
            int16_t shortVal;
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
        }
        case GS_TYPE_INTEGER:
            if (PyBool_Check(value)) {
                return false;
            }
            checkConvert = SWIG_AsVal_int(value, &intVal);
            if (!SWIG_IsOK(checkConvert)) {
                return false;
            }
            ret = gsSetRowFieldByInteger(row, column, intVal);
            break;
        case GS_TYPE_FLOAT: {
            float floatVal;
            vbool = convertObjectToFloat(value, &floatVal);
            if (!vbool) {
                return false;
            }
            ret = gsSetRowFieldByFloat(row, column, floatVal);
            break;
        }
        case GS_TYPE_DOUBLE: {
            double doubleVal;
            vbool = convertObjectToDouble(value, &doubleVal);
            if (!vbool) {
                return false;
            }
            ret = gsSetRowFieldByDouble(row, column, doubleVal);
            break;
        }
        case GS_TYPE_TIMESTAMP: {
            GSTimestamp timestampVal;
            vbool = convertObjectToGSTimestamp(value, &timestampVal);
            if (!vbool) {
                return false;
            }
            ret = gsSetRowFieldByTimestamp(row, column, timestampVal);
            break;
        }
        case GS_TYPE_BLOB: {
            GSBlob blobValTmp = {0};
            GSBlob *blobVal = &blobValTmp;
            vbool = convertObjectToBlob(value, &blobVal->size, (void**) &blobVal->data);
            if (!vbool) {
                return false;
            }
            ret = gsSetRowFieldByBlob(row, column, (const GSBlob *)blobVal);
            if (blobVal->data) {
                delete [] (GSChar*)blobVal->data;
            }
            break;
        }
        case GS_TYPE_STRING_ARRAY: {
            GSChar **stringArrVal;
            vbool = convertObjectToStringArray(value, &stringArrVal, &size);
            if (!vbool) {
                return false;
            }
            ret = gsSetRowFieldByStringArray(row, column, stringArrVal, size);
            cleanStringArray(stringArrVal, size);
            break;
        }
        case GS_TYPE_GEOMETRY: {
            GSChar *geometryVal;
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
        }
        case GS_TYPE_INTEGER_ARRAY: {
            int32_t *intArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                intArrVal = new int32_t[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = PyBool_Check(PyList_GetItem(value, i));
                checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &intArrVal[i]);
                if (!SWIG_IsOK(checkConvert) || vbool) {
                    delete [] intArrVal;
                    return false;
                }
            }
            ret = gsSetRowFieldByIntegerArray(row, column, (const int32_t *) intArrVal, size);
            delete [] intArrVal;
            break;
        }
        case GS_TYPE_BOOL_ARRAY: {
            GSBool *boolArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                boolArrVal = new GSBool[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = convertObjectToBool(PyList_GetItem(value, i), &boolArrVal[i]);
                if (!vbool) {
                    delete [] boolArrVal;
                    return false;
                }
            }
            ret = gsSetRowFieldByBoolArray(row, column, (const GSBool *)boolArrVal, size);
            delete [] boolArrVal;
            break;
        }
        case GS_TYPE_BYTE_ARRAY: {
            int8_t *byteArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                byteArrVal = new int8_t[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = PyBool_Check(PyList_GetItem(value, i));
                checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &tmpInt);
                *(((int8_t*)byteArrVal + i)) = (int8_t)tmpInt;
                 if (vbool || !SWIG_IsOK(checkConvert) ||
                    tmpInt < std::numeric_limits<int8_t>::min() ||
                    tmpInt > std::numeric_limits<int8_t>::max()) {
                     delete [] byteArrVal;
                     return false;
                }
            }
            ret = gsSetRowFieldByByteArray(row, column, (const int8_t *)byteArrVal, size);
            delete [] byteArrVal;
            break;
        }
        case GS_TYPE_SHORT_ARRAY: {
            int16_t *shortArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                shortArrVal = new int16_t[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = PyBool_Check(PyList_GetItem(value, i));
                checkConvert = SWIG_AsVal_int(PyList_GetItem(value, i), &tmpInt);
                *(((int16_t*)shortArrVal + i)) = (int16_t)tmpInt;
                if (vbool || !SWIG_IsOK(checkConvert) ||
                    tmpInt < std::numeric_limits<int16_t>::min() ||
                    tmpInt > std::numeric_limits<int16_t>::max()) {
                        delete [] shortArrVal;
                        return false;
                }
            }
            ret = gsSetRowFieldByShortArray(row, column, (const int16_t *)shortArrVal, size);
            delete [] shortArrVal;
            break;
        }
        case GS_TYPE_LONG_ARRAY: {
            int64_t *longArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                longArrVal = new int64_t[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = PyBool_Check(PyList_GetItem(value, i));
                checkConvert = SWIG_AsVal_dec(long long)(PyList_GetItem(value, i), ((long long *)longArrVal + i));
                if (!SWIG_IsOK(checkConvert) || vbool) {
                    delete [] longArrVal;
                    return false;
                }
            }
            ret = gsSetRowFieldByLongArray(row, column, (const int64_t *)longArrVal, size);
            delete [] longArrVal;
            break;
        }
        case GS_TYPE_FLOAT_ARRAY: {
            float *floatArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                floatArrVal = new float[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = convertObjectToFloat(PyList_GetItem(value, i), &floatArrVal[i]);
                if (!vbool) {
                    delete [] floatArrVal;
                    return false;
                }
            }
            ret = gsSetRowFieldByFloatArray(row, column, (const float *) floatArrVal, size);
            delete [] floatArrVal;
            break;
        }
        case GS_TYPE_DOUBLE_ARRAY: {
            double *doubleArrVal;
            double tmpDouble; //support convert to double array
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                doubleArrVal = new double[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            for (i = 0; i < size; i++) {
                vbool = convertObjectToDouble(PyList_GetItem(value, i), &tmpDouble);
                *((double *)doubleArrVal + i) = tmpDouble;
                if (!vbool){
                    delete [] doubleArrVal;
                    return false;
                }
            }
            ret = gsSetRowFieldByDoubleArray(row, column, (const double *)doubleArrVal, size);
            delete [] doubleArrVal;
            break;
        }
        case GS_TYPE_TIMESTAMP_ARRAY: {
            GSTimestamp *timestampArrVal;
            if (!PyList_Check(value)) {
                return false;
            }
            size = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(value)));
            try {
                timestampArrVal = new GSTimestamp[size]();
            } catch (bad_alloc& ba) {
                return false;
            }
            bool checkRet;
            for (i = 0; i < size; i++) {
                checkRet = convertObjectToGSTimestamp(PyList_GetItem(value, i), ((GSTimestamp *)timestampArrVal + i));
                if (!checkRet) {
                    delete [] timestampArrVal;
                    return false;
                }
            }
            ret = gsSetRowFieldByTimestampArray(row, column, (const GSTimestamp *)timestampArrVal, size);
            delete [] timestampArrVal;
            break;
        }
        default:
            //Not support for now
            return false;
            break;
    }
    return (ret == GS_RESULT_OK);
}
}

/**
* Typemaps for new ContainerInfo()
*/
%typemap(in, fragment = "SWIG_AsCharPtrAndSize", fragment = "cleanString")
        (const GSColumnInfo* props, int propsCount)
(PyObject* list, int i, size_t size = 0, int* alloc = 0, int res, char* v = 0) {
//Convert Python list of tuple into GSColumnInfo properties
    if (!PyList_Check($input)) {
        $2 = 0;
        $1 = NULL;
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        try {
            $1    = new GSColumnInfo[$2]();
            alloc = new int[$2]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }

        i = 0;
        while (i < $2) {
            list = PyList_GetItem($input, i);
            if (!PyList_Check(list)) {
                PyErr_SetString(PyExc_ValueError, "Expected a List as List element");
                SWIG_fail;
            }
            int tupleLength = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(list)));
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
                if (i == 0) {
                    $1[i].options = GS_TYPE_OPTION_NOT_NULL;
                } else {
                    $1[i].options = GS_TYPE_OPTION_NULLABLE;
                }
            } else {
                PyErr_SetString(PyExc_ValueError, "Invalid element number for List");
                SWIG_fail;
            }

            res = SWIG_AsCharPtrAndSize(PyList_GetItem(list, 0), &v, &size, &alloc[i]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "name");
            }
            if (v) {
                try {
                    griddb::Util::strdup((const GSChar** const)&($1[i].name), v);
                    cleanString(v, alloc[i]);
                } catch (bad_alloc& ba) {
                    cleanString(v, alloc[i]);
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
            if ($1[i].name) {
                delete [] $1[i].name;
            }
        }
        delete [] $1;
    }

    if (alloc$argnum) {
        delete [] alloc$argnum;
    }
}

%typemap(doc, name = "column_info_list") (const GSColumnInfo* props, int propsCount) "list[list[string, Type, TypeOption]]";
/**
* Typemaps for StoreFactory::set_properties() function
*/
%typemap(in, fragment = "SWIG_AsCharPtrAndSize", fragment = "cleanString") (const GSPropertyEntry* props, int propsCount)
(int i, int j, Py_ssize_t si, PyObject* key, PyObject* val, size_t size = 0, int* alloc = 0, int res, char* v = 0) {
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        try {
            $1    = new GSPropertyEntry[$2]();
            alloc = new int[$2]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        i = 0;
        j = 0;
        si = 0;
        while (PyDict_Next($input, &si, &key, &val)) {
            res = SWIG_AsCharPtrAndSize(key, &v, &size, &alloc[j]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "name");
            }

            if (v) {
                try {
                    griddb::Util::strdup((const GSChar** const)&($1[i].name), v);
                    cleanString(v, alloc[j]);
                } catch (bad_alloc& ba) {
                    cleanString(v, alloc[j]);
                    PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                    SWIG_fail;
                }
            } else {
                $1[i].name = NULL;
            }
            res = SWIG_AsCharPtrAndSize(val, &v, &size, &alloc[j + 1]);
            if (!SWIG_IsOK(res)) {
                %variable_fail(res, "String", "value");
            }
            if (v) {
                try {
                    griddb::Util::strdup((const GSChar** const)&($1[i].value), v);
                    cleanString(v, alloc[j + 1]);
                } catch (bad_alloc& ba) {
                    cleanString(v, alloc[j + 1]);
                    PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                    SWIG_fail;
                }
            } else {
                $1[i].value = NULL;
            }
            i++;
            j+=2;
        }
    }
}

%typemap(freearg) (const GSPropertyEntry* props, int propsCount)  (int i = 0, int j = 0) {
    if ($1) {
        for (int i = 0; i < $2; i++) {
           if ($1[i].name) {
                delete [] $1[i].name;
            }
            if ($1[i].value) {
                delete [] $1[i].value;
            }
            j += 2;
        }
        delete [] $1;
    }

    if (alloc$argnum) {
        delete [] alloc$argnum;
    }
}

/**
* Typemaps for fetch_all() function
*/
%typemap(in) (GSQuery* const* queryList, size_t queryCount)
        (PyObject* pyQuery, std::shared_ptr<griddb::Query> query, void *vquery, int i, int res = 0) {
    if ($input == Py_None) {
        $1 = NULL;
        $2 = 0;
    } else if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    } else {
        $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
        $1 = NULL;
        i = 0;
        if ($2 > 0) {
            try {
                $1 = new GSQuery*[$2]();
            } catch (bad_alloc& ba) {
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
}

%typemap(freearg) (GSQuery* const* queryList, size_t queryCount) {
    if ($1) {
        delete [] $1;
    }
}

%typemap(doc, name = "query_list") (GSQuery* const* queryList, size_t queryCount) "list[Query] query_list";

/**
* Typemaps input for multi_get() function
*/

%typemap(in, fragment = "SWIG_AsCharPtrAndSize") (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount
        , GSContainerRowEntry **entryList, size_t* containerCount, int **colNumList, GSType*** typeList, int **orderFromInput)
        (PyObject* key, PyObject* val, std::shared_ptr<griddb::RowKeyPredicate> pPredicate, GSRowKeyPredicateEntry* pList = NULL,
                void *vpredicate, Py_ssize_t si, int i, int res = 0, size_t size = 0, int* alloc = 0, char* v = 0,
                GSContainerRowEntry *tmpEntryList, size_t tmpContainerCount, int *tmpcolNumList, GSType** tmpTypeList, int *tmpOrderFromInput) {
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }
    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    $1 = NULL;
    $3 = &tmpEntryList;
    $4 = &tmpContainerCount;
    $5 = &tmpcolNumList;
    $6 = &tmpTypeList;
    $7 = &tmpOrderFromInput;
    i = 0;
    si = 0;
    if ($2 > 0) {
        try {
            pList = new GSRowKeyPredicateEntry[$2]();
            alloc = new int[$2]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
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
            } else {
                predicateEntry->predicate = NULL;
            }
            i++;
        }

    }
}

%typemap(argout, numinputs = 1, fragment = "convertStrToObj", fragment = "getRowFields")
        (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount
                , GSContainerRowEntry **entryList, size_t* containerCount, int **colNumList, GSType*** typeList, int **orderFromInput) () {
    PyObject* dict = PyDict_New();
    GSRow* row;
    bool retVal;
    int errorColumn;
    GSType errorType;
    for (int i = 0; i < *$4; i++) {
        PyObject* key = convertStrToObj((*$3)[i].containerName);
        PyObject* list = PyList_New((*$3)[i].rowCount);
        for (int j = 0; j < (*$3)[i].rowCount; j++) {
            row = (GSRow*)(*$3)[i].rowList[j];
            PyObject *outList = PyList_New((*$5)[i]);
            if (outList == NULL) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                SWIG_fail;
            }
            retVal = getRowFields(row, (*$5)[i], (*$6)[i], arg1->timestamp_output_with_float, &errorColumn, &errorType, outList);
            if (retVal == false) {
                char errorMsg[60];
                sprintf(errorMsg, "Can't get data for field %d with type %d", errorColumn, errorType);
                PyErr_SetString(PyExc_ValueError, errorMsg);
                SWIG_fail;
            }
            PyList_SetItem(list, j, outList);
        }

        //Add entry to map
        PyDict_SetItem(dict, key, list);
        Py_DECREF(key);
        Py_DECREF(list);
    }
    $result = dict;
}

%typemap(freearg, fragment = "cleanString") (const GSRowKeyPredicateEntry *const * predicateList, size_t predicateCount
        , GSContainerRowEntry **entryList, size_t* containerCount, int **colNumList, GSType*** typeList, int **orderFromInput) (int i) {
    if ($1 && *$1) {
        for (int i = 0; i < $2; i++) {
            cleanString((*$1)[i].containerName, alloc$argnum[i]);
        }
    }

    if (pList$argnum) {
        delete [] pList$argnum;
    }
    if (alloc$argnum) {
        delete [] alloc$argnum;
    }

    if (*$5) {
        delete [] *$5;
    }
    if (*$6) {
        for (int j = 0; j < (int) $2; j++) {
            if ((*$6)[j]) {
                delete [] (*$6)[j];
            }
        }
        delete [] (*$6);
    }
    if ($3) {
        GSRow* row;
        for (int i = 0; i < *$4; i++) {
            for (int j = 0; j < (*$3)[i].rowCount; j++) {
                row = (GSRow*)(*$3)[i].rowList[j];
                gsCloseRow(&row);
            }
        }
    }
    if (*$7) {
        delete [] *$7;
    }
}

/**
* Typemaps output for partition controller function
*/
%typemap(in, numinputs = 0) (const GSChar *const ** stringList, size_t *size) (GSChar **nameList1, size_t size1) {
    $1 = &nameList1;
    $2 = &size1;
}

%typemap(argout, numinputs = 0, fragment = "convertStrToObj") (const GSChar *const ** stringList, size_t *size) (  int i, size_t size) {
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
        PyObject* obj = PyFloat_FromDouble(longList[i]);
        PyList_SetItem($result, i, obj);
    }
}

%typemap(out, fragment = "convertStrToObj") GSColumnInfo {
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
* Typemaps for RowSet.update() function
*/
%typemap(in, fragment = "convertToFieldWithType") (GSRow* row) {
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
    for (int i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if (!(convertToFieldWithType(tmpRow, i, PyList_GetItem($input, i), type))) {
            char gsType[200];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }
}

/**
* Typemaps for put_row() function
*/
%typemap(in, fragment = "convertToFieldWithType") (GSRow *rowContainer) {
    $1 = NULL;
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int leng = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));

    if (leng != arg1->getColumnCount()) {
        %variable_fail(1, "Row", "num row is different with container info");
    }

    GSRow* row = arg1->getGSRowPtr();
    GSType* typeList = arg1->getGSTypeList();
    for (int i = 0; i < leng; i++) {
        GSType type = typeList[i];
        if (!(convertToFieldWithType(row, i, PyList_GetItem($input, i), type))) {
            char gsType[60];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            PyErr_SetString(PyExc_ValueError, gsType);
            SWIG_fail;
        }
    }
}

%typemap(doc, name = "row") (GSRow *rowContainer) "list[object]";

/*
* typemap for get_row
*/

%typemap(in, fragment = "convertToRowKeyFieldWithType") (griddb::Field* keyFields)(griddb::Field field) {
    $1 = &field;
    if ($input == Py_None) {
        $1->type = GS_TYPE_NULL;
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

/**
 * Support convert data from GSRow* row to Python list
 */
%fragment("getRowFields", "header", fragment = "checkNullField",
        fragment = "convertStrToObj", fragment = "convertTimestampToObject") {
static bool getRowFields(GSRow* row, int columnCount, GSType* typeList, bool timestampOutput, int* columnError,
        GSType* fieldTypeError, PyObject* outList) {
    GSResult ret;
    bool retVal = true;
    for (int i = 0; i < columnCount; i++) {
        // Column and type index in error case
        *columnError = i;
        *fieldTypeError = typeList[i];

        switch (typeList[i]) {
            case GS_TYPE_LONG: {
                int64_t longValue;
                ret = gsGetRowFieldAsLong(row, (int32_t) i, &longValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (longValue) {
                    PyList_SetItem(outList, i, PyLong_FromLong(longValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyLong_FromLong(longValue));
                }
                break;
            }
            case GS_TYPE_STRING: {
                GSChar* stringValue;
                ret = gsGetRowFieldAsString(row, (int32_t) i,
                    (const GSChar **)&stringValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if ((stringValue != NULL) && (stringValue[0] == '\0')) {
                    // Empty string
                    if (checkNullField(row, i)) {
                        // NULL value
                        Py_INCREF(Py_None);
                        PyList_SetItem(outList, i, Py_None);
                    } else {
                        PyList_SetItem(outList, i,
                                convertStrToObj(stringValue));
                    }
                } else {
                    PyList_SetItem(outList, i, convertStrToObj(stringValue));
                }

                break;
            }
            case GS_TYPE_BLOB: {
                GSBlob blobValue = {0};
                ret = gsGetRowFieldAsBlob(row, (int32_t) i, &blobValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (blobValue.size) {
                    PyList_SetItem(outList, i,
                        PyByteArray_FromStringAndSize(
                                (const char*)blobValue.data, blobValue.size));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i,
                        PyByteArray_FromStringAndSize(
                                (const char*)blobValue.data, blobValue.size));
                }
                break;
            }
            case GS_TYPE_BOOL: {
                GSBool boolValue;
                ret = gsGetRowFieldAsBool(row, (int32_t) i, &boolValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (boolValue) {
                    PyList_SetItem(outList, i, PyBool_FromLong(boolValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyBool_FromLong(boolValue));
                }
                break;
            }
            case GS_TYPE_INTEGER: {
                int32_t intValue;
                ret = gsGetRowFieldAsInteger(row, (int32_t) i, &intValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (intValue) {
                    PyList_SetItem(outList, i, PyInt_FromLong(intValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyInt_FromLong(intValue));
                }
                break;
            }
            case GS_TYPE_FLOAT: {
                float floatValue;
                ret = gsGetRowFieldAsFloat(row, (int32_t) i, &floatValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (floatValue) {
                    PyList_SetItem(outList, i, PyFloat_FromDouble(floatValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyFloat_FromDouble(floatValue));
                }
                break;
            }
            case GS_TYPE_DOUBLE: {
                double doubleValue;
                ret = gsGetRowFieldAsDouble(row, (int32_t) i, &doubleValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (doubleValue) {
                    PyList_SetItem(outList, i, PyFloat_FromDouble(doubleValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyFloat_FromDouble(doubleValue));
                }
                break;
            }
            case GS_TYPE_TIMESTAMP: {
                GSTimestamp timestampValue;
                ret = gsGetRowFieldAsTimestamp(row,
                        (int32_t) i, &timestampValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (timestampValue) {
                    PyList_SetItem(outList, i,
                        convertTimestampToObject(&timestampValue, timestampOutput));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i,
                        convertTimestampToObject(&timestampValue, timestampOutput));
                }
                break;
            }
            case GS_TYPE_BYTE: {
                int8_t byteValue;
                ret = gsGetRowFieldAsByte(row, (int32_t) i, &byteValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (byteValue) {
                    PyList_SetItem(outList, i, PyInt_FromLong(byteValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyInt_FromLong(byteValue));
                }
                break;
            }
            case GS_TYPE_SHORT: {
                int16_t shortValue;
                ret = gsGetRowFieldAsShort(row, (int32_t) i, &shortValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if (shortValue) {
                    PyList_SetItem(outList, i, PyInt_FromLong(shortValue));
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, PyInt_FromLong(shortValue));
                }
                break;
            }
            case GS_TYPE_GEOMETRY: {
                GSChar* geoValue;
                ret = gsGetRowFieldAsGeometry(row, (int32_t) i, (const GSChar **)&geoValue);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                if ((geoValue != NULL) && (geoValue[0] == '\0')) {
                    // Empty string
                    if (checkNullField(row, i)) {
                        // NULL value
                        Py_INCREF(Py_None);
                        PyList_SetItem(outList, i, Py_None);
                    } else {
                        PyList_SetItem(outList, i, convertStrToObj(geoValue));
                    }
                } else {
                    PyList_SetItem(outList, i, convertStrToObj(geoValue));
                }
                break;
            }
            case GS_TYPE_INTEGER_ARRAY: {
                int32_t* intArr;
                size_t size;
                ret = gsGetRowFieldAsIntegerArray(row, (int32_t) i,
                        (const int32_t **)&intArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, PyInt_FromLong(intArr[j]));
                }

                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_STRING_ARRAY: {
                GSChar** stringArrVal;
                size_t size;
                ret = gsGetRowFieldAsStringArray(row, (int32_t) i,
                        (const GSChar *const **)&stringArrVal, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, convertStrToObj(stringArrVal[j]));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_BOOL_ARRAY: {
                GSBool* boolArr;
                size_t size;
                ret = gsGetRowFieldAsBoolArray(row, (int32_t) i,
                        (const GSBool **)&boolArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, PyBool_FromLong(boolArr[j]));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_BYTE_ARRAY: {
                int8_t* byteArr;
                size_t size;
                ret = gsGetRowFieldAsByteArray(row, (int32_t) i,
                        (const int8_t **)&byteArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, PyInt_FromLong(byteArr[j]));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_SHORT_ARRAY: {
                int16_t* shortArr;
                size_t size;
                ret = gsGetRowFieldAsShortArray(row, (int32_t) i,
                        (const int16_t **)&shortArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, PyInt_FromLong(shortArr[j]));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_LONG_ARRAY: {
                int64_t* longArr;
                size_t size;
                ret = gsGetRowFieldAsLongArray(row, (int32_t) i,
                        (const int64_t **)&longArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, PyLong_FromLong(longArr[j]));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_FLOAT_ARRAY: {
                float* floatArr;
                size_t size;
                ret = gsGetRowFieldAsFloatArray(row, (int32_t) i,
                        (const float **)&floatArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j,
                            PyFloat_FromDouble(static_cast<double>(floatArr[j])));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_DOUBLE_ARRAY: {
                double* doubleArr;
                size_t size;
                ret = gsGetRowFieldAsDoubleArray(row, (int32_t) i,
                        (const double **)&doubleArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j, PyFloat_FromDouble(doubleArr[j]));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            case GS_TYPE_TIMESTAMP_ARRAY: {
                GSTimestamp* timestampArr;
                size_t size;
                ret = gsGetRowFieldAsTimestampArray(row, (int32_t) i,
                        (const GSTimestamp **)&timestampArr, &size);
                if (ret != GS_RESULT_OK) {
                    return false;
                }
                PyObject* list = PyList_New(size);
                if (!list) {
                    return false;
                }
                for (int j = 0; j < size; j++) {
                    PyList_SetItem(list, j,
                            convertTimestampToObject(&timestampArr[j], timestampOutput));
                }
                if (size) {
                    PyList_SetItem(outList, i, list);
                } else if (checkNullField(row, i)) {
                    // NULL value
                    Py_INCREF(Py_None);
                    PyList_SetItem(outList, i, Py_None);
                } else {
                    PyList_SetItem(outList, i, list);
                }
                break;
            }
            default: {
                // NOT OK
                retVal = false;
                break;
            }
        }
    }
    return retVal;
}
}

%typemap(argout, fragment = "getRowFields") (GSRow *rowdata) {
    if (result == GS_FALSE) {
        Py_RETURN_NONE;
    } else {
        GSRow* row = arg1->getGSRowPtr();
        PyObject *outList = PyList_New(arg1->getColumnCount());
        if (outList == NULL) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
            SWIG_fail;
        }
        bool retVal;
        int errorColumn;
        GSType errorType;
        retVal = getRowFields(row, arg1->getColumnCount(), arg1->getGSTypeList(), arg1->timestamp_output_with_float, &errorColumn, &errorType, outList);
        if (retVal == false) {
            char errorMsg[60];
            sprintf(errorMsg, "Can't get data for field %d with type%d", errorColumn, errorType);
            PyErr_SetString(PyExc_ValueError, errorMsg);
            SWIG_fail;
        }
        $result = outList;
    }
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

%typemap(argout, fragment = "convertFieldToObject") (griddb::Field* startField, griddb::Field* finishField) {
    int length = 2;
    $result = PyList_New(2);
    if ($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    if ($1->type != -1) { // -1 for all versions which do not support GS_TYPE_NULL
        PyList_SetItem($result, 0, convertFieldToObject(&($1->value), $1->type, arg1->timestamp_output_with_float));
    } else {
        PyList_SetItem($result, 0, Py_None);
    }
    if ($2->type != -1) { // -1 for all versions which do not support GS_TYPE_NULL
        PyList_SetItem($result, 1, convertFieldToObject(&($2->value), $1->type, arg1->timestamp_output_with_float));
    } else {
        PyList_SetItem($result, 1, Py_None);
    }
}

/**
 * Typemap for RowKeyPredicate.set_distinct_keys
 */
%typemap(in, fragment = "convertToRowKeyFieldWithType") (const griddb::Field *keys, size_t keyCount) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    $2 = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1 = NULL;
    if ($2 > 0) {
        try {
            $1 = new griddb::Field[$2]();
        } catch (bad_alloc& ba) {
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

%typemap(argout, numinputs = 0, fragment = "convertFieldToObject") (griddb::Field **keys, size_t* keyCount) (int i, size_t size) {
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
%typemap(in, fragment = "convertToFieldWithType", fragment = "convertObjToStr")
        (GSRow*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) () {
    $1 = NULL;
    $2 = NULL;
    $3 = NULL;
    $4 = 0;
    if (!PyDict_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a Dict");
        SWIG_fail;
    }

    $4 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyDict_Size($input)));
    griddb::Container* tmpContainer;
    if ($4 > 0) {
        try {
            $1 = new GSRow**[$4]();
            $2 = new int[$4]();
            $3 = new char*[$4]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        int i = 0;
        int j = 0;
        //End init
        Py_ssize_t si = 0;
        PyObject* containerName;
        PyObject* listRowContainer;
        ColumnInfoList infoListTmp;
        while (PyDict_Next($input, &si, &containerName, &listRowContainer)) {
            int numRowOfContainer = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(listRowContainer)));
            if (numRowOfContainer <= 0) {
                PyErr_SetString(PyExc_ValueError, "Num rows of container is invalid.");
                SWIG_fail;
            }
            try {
                $1[i] = new GSRow* [numRowOfContainer]();
            } catch (bad_alloc& ba) {
                PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                SWIG_fail;
            }
            //End init
            $2[i] = numRowOfContainer;
            $3[i] = convertObjToStr(containerName);
            int length;
            tmpContainer = arg1->get_container($3[i]);
            if (tmpContainer == NULL) {
                PyErr_SetString(PyExc_ValueError, "Not found container");
                SWIG_fail;
            }
            GSType* typeArr = tmpContainer->getGSTypeList();
            for (j = 0; j < numRowOfContainer; j++) {
                PyObject* rowTmp = PyList_GetItem(listRowContainer, j);
                if (!PyList_Check(rowTmp)) {
                    PyErr_SetString(PyExc_ValueError, "Expected a List");
                    delete tmpContainer;
                    SWIG_fail;
                }
                length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
                GSResult ret = gsCreateRowByContainer(tmpContainer->getGSContainerPtr(), &$1[i][j]);
                if ($1[i][j] == NULL || ret != GS_RESULT_OK) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation error");
                    delete tmpContainer;
                    SWIG_fail;
                }
                for (int k = 0; k < length; k++) {
                    if (!(convertToFieldWithType($1[i][j], k, PyList_GetItem(rowTmp, k), (int) typeArr[k]))) {
                        char gsType[200];
                        sprintf(gsType, "Invalid value for column %d, type should be : %d", k, typeArr[k]);
                        PyErr_SetString(PyExc_ValueError, gsType);
                        delete tmpContainer;
                        SWIG_fail;
                    }
                }
            }
            delete tmpContainer;
            i++;
        }

    }
}

%typemap(doc, name = "container_entry") (GSRow*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) "dict{string name : list[list[object]] row_list} container_entry";

%typemap(freearg) (GSRow*** listRow, const int *listRowContainerCount, const char ** listContainerName, size_t containerCount) {
    for (int i = 0; i < $4; i++) {
        if ($1[i] != NULL) {
            for (int j = 0; j < $2[i]; j++) {
                gsCloseRow(&$1[i][j]);
            }
            delete [] $1[i];
        }
    }
    if ($1) delete [] $1;
    if ($2) delete $2;
    if ($3) delete $3;
}

/**
 * Typemap for QueryAnalysisEntry.get()
 */
%typemap(in, numinputs = 0) (GSQueryAnalysisEntry* queryAnalysis) (GSQueryAnalysisEntry queryAnalysis1) {
    queryAnalysis1 = GS_QUERY_ANALYSIS_ENTRY_INITIALIZER;
    $1 = &queryAnalysis1;
}

%typemap(argout, fragment = "convertStrToObj") (GSQueryAnalysisEntry* queryAnalysis) () {
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
            delete [] $1->statement;
        }
        if ($1->type) {
            delete [] $1->type;
        }
        if ($1->value) {
            delete [] $1->value;
        }
        if ($1->valueType) {
            delete [] $1->valueType;
        }
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

%typemap(argout, numinputs = 0, fragment = "convertStrToObj") (char*** listName, int* num) {
    $result = PyList_New(*$2);
    if (*$2 && *$1){
        for (int i = 0; i < *$2; i++) {
            PyList_SetItem($result, i, convertStrToObj((*$1)[i]));
            if ((*$1)[i]) {
                delete [] ((*$1)[i]);
            }
        }
        delete [] (*$1);
    }
    return $result;
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
%attribute(griddb::ContainerInfo, griddb::ExpirationInfo*, expiration, get_expiration_info, set_expiration_info);
//Read only attribute ExpirationInfo::time
%attribute(griddb::ExpirationInfo, int, time, get_time, set_time);
//Read and write attribute ExpirationInfo::unit
%attribute(griddb::ExpirationInfo, GSTimeUnit, unit, get_time_unit, set_time_unit);
//Read and write attribute ExpirationInfo::divisionCount
%attribute(griddb::ExpirationInfo, int, division_count, get_division_count, set_division_count);

//Attribute ContainerInfo::columnInfoList
#if SWIG_VERSION < 0x040000
%extend griddb::ContainerInfo{
    %pythoncode %{
        __swig_getmethods__["column_info_list"] = get_column_info_list
        __swig_setmethods__["column_info_list"] = set_column_info_list
    %}
};
#endif

/**
 * Typemap for Container::multi_put
 */
%typemap(in, fragment = "convertToFieldWithType") (GSRow** listRowdata, int rowCount) {
    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    $1 = NULL;
    $2 = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    GSResult ret;
    if ($2 > 0) {
        GSContainer *mContainer = arg1->getGSContainerPtr();
        GSType* typeList = arg1->getGSTypeList();
        try {
            $1 = new GSRow*[$2]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        int length;
        GSType type;
        int columnCount = arg1->getColumnCount();
        for (int i = 0; i < $2; i++) {
            PyObject* rowTmp = PyList_GetItem($input, i);
            length = (int)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(rowTmp)));
            if (length != columnCount) {
                $2 = i;
                %variable_fail(1, "Row", "num row is different with container info");
            }
            ret = gsCreateRowByContainer(mContainer, &$1[i]);
            if (ret != GS_RESULT_OK) {
                $2 = i;
                PyErr_SetString(PyExc_ValueError, "Can't create GSRow");
                SWIG_fail;
            }
            for (int k = 0; k < length; k++) {
                type = typeList[k];
                PyObject* fieldObj = PyList_GetItem(rowTmp, k);
                if (!(convertToFieldWithType($1[i], k, fieldObj, type))) {
                    $2 = i + 1;
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
    if ($1 != NULL) {
        for (int rowNum = 0; rowNum < $2; rowNum++) {
            gsCloseRow(&$1[rowNum]);
        }
        delete [] $1;
    }
}

%typemap(doc, name = "row_list") (GSRow** listRowdata, int rowCount) "list[list[object]]";

//attribute ContainerInfo::column_info_list
%typemap(in, fragment = "SWIG_AsCharPtrAndSize", fragment = "cleanString") (ColumnInfoList columnInfoList) (int* alloc = NULL){

    if (!PyList_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Expected a List");
        SWIG_fail;
    }
    int res;
    char* v = 0;
    bool vbool;
    size_t size = 0;
    size = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size($input)));
    $1.columnInfo = NULL;
    $1.size = size;
    size_t stringSize = 0;
    if (size) {
        try {
            alloc         = new int[size]();
            $1.columnInfo = new GSColumnInfo[size]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation for set column_info_list is error");
            SWIG_fail;
        }
        PyObject* columInfoList;
        int option;
        for (int i = 0; i < size; i++) {
            $1.columnInfo[i] = GS_COLUMN_INFO_INITIALIZER;
            columInfoList = PyList_GetItem($input, i);
            if (!PyList_Check(columInfoList)) {
                PyErr_SetString(PyExc_ValueError, "Expected a List");
                SWIG_fail;
            }
            size_t sizeColumn = (size_t)PyInt_AsLong(PyLong_FromSsize_t(PyList_Size(columInfoList)));
            if (sizeColumn == 3) {
                option = PyInt_AsLong(PyList_GetItem(columInfoList, 2));
                $1.columnInfo[i].options = option;
                if (option != GS_TYPE_OPTION_NULLABLE && option != GS_TYPE_OPTION_NOT_NULL) {
                    PyErr_SetString(PyExc_ValueError, "Invalid value for column option");
                    SWIG_fail;
                }
            } else if (sizeColumn == 2) {
                    if (i == 0) {
                        $1.columnInfo[i].options = GS_TYPE_OPTION_NOT_NULL;
                    } else {
                        $1.columnInfo[i].options = GS_TYPE_OPTION_NULLABLE;
                    }
            } else {
                PyErr_SetString(PyExc_ValueError, "Invalid element number for List");
                SWIG_fail;
            }

            res = SWIG_AsCharPtrAndSize(PyList_GetItem(columInfoList, 0), &v, &stringSize, &alloc[i]);
            if (!SWIG_IsOK(res)) {
                PyErr_SetString(PyExc_ValueError, "Can't convert field to string");
                SWIG_fail;
            }
            $1.columnInfo[i].name = v;
            $1.columnInfo[i].type = PyInt_AsLong(PyList_GetItem(columInfoList, 1));
        }
    }
}

%typemap(freearg, fragment = "cleanString") (ColumnInfoList columnInfoList) {
    size_t size = 0;
    if ($1.size) {
        size = $1.size;
    }
    if ($1.columnInfo != NULL) {
        if (alloc$argnum) {
            for (int i = 0; i < size; i++) {
                if ($1.columnInfo[i].name) {
                    cleanString($1.columnInfo[i].name, alloc$argnum[i]);
                }
            }
        }
        delete [] $1.columnInfo;
    }
    if (alloc$argnum) {
        delete [] alloc$argnum;
    }
}

%typemap(out, fragment = "convertStrToObj") (ColumnInfoList) {
    ColumnInfoList data = $1;
    size_t size = data.size;
    $result = PyList_New(size);
    if ($result == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for column_info_list is error");
        SWIG_fail;
    }
    PyObject* info;
    for (int i = 0; i < size; i++) {
        if ((data.columnInfo)[i].options != 0) {
            info = PyList_New(3);
            PyList_SetItem(info, 0, convertStrToObj((data.columnInfo)[i].name));
            PyList_SetItem(info, 1, PyInt_FromLong((data.columnInfo)[i].type));
            PyList_SetItem(info, 2, PyInt_FromLong((data.columnInfo)[i].options));
        } else {
            info = PyList_New(2);
            PyList_SetItem(info, 0, convertStrToObj((data.columnInfo)[i].name));
            PyList_SetItem(info, 1, PyInt_FromLong((data.columnInfo)[i].type));
        }
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

%typemap(argout, fragment = "getRowFields") (GSRowSetType* type, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {

    switch (*$1) {
        case (GS_ROW_SET_CONTAINER_ROWS): {
            bool retVal;
            int errorColumn;
            if (*$2 == false) {
                PyErr_SetNone(PyExc_StopIteration);
                return NULL;
            } else {
                GSRow* row = arg1->getGSRowPtr();
                PyObject *outList = PyList_New(arg1->getColumnCount());
                if (outList == NULL) {
                    PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
                    SWIG_fail;
                }
                GSType errorType;
                retVal = getRowFields(row, arg1->getColumnCount(), arg1->getGSTypeList(), arg1->timestamp_output_with_float, &errorColumn, &errorType, outList);
                if (retVal == false) {
                    char errorMsg[60];
                    sprintf(errorMsg, "Can't get data for field %d with type%d", errorColumn, errorType);
                    PyErr_SetString(PyExc_ValueError, errorMsg);
                    SWIG_fail;
                }
                $result = outList;
            }
            break;
        }
        case (GS_ROW_SET_AGGREGATION_RESULT): {
            std::shared_ptr< griddb::AggregationResult > *aggResult = NULL;
            if (*$2 == false) {
                Py_RETURN_NONE;
            } else {
                aggResult = *$4 ? new std::shared_ptr<  griddb::AggregationResult >(*$4 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
                $result = SWIG_NewPointerObj(SWIG_as_voidptr(aggResult), SWIGTYPE_p_std__shared_ptrT_griddb__AggregationResult_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
            }
            break;
        }
        case (GS_ROW_SET_QUERY_ANALYSIS): {
            std::shared_ptr< griddb::QueryAnalysisEntry >* queryAnalyResult = NULL;
            if (*$2 == false) {
                Py_RETURN_NONE;
            } else {
                queryAnalyResult = *$3 ? new std::shared_ptr<  griddb::QueryAnalysisEntry >(*$3 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
                $result = SWIG_NewPointerObj(SWIG_as_voidptr(queryAnalyResult), SWIGTYPE_p_std__shared_ptrT_griddb__QueryAnalysisEntry_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
            }
            break;
        }
        default: {
            PyErr_SetString(PyExc_ValueError, "Invalid type");
            SWIG_fail;
            break;
        }
    }
    return $result;
}

//Correct check for input integer: when input invalid value (boolean), should throw exception
%typemap(in) (int32_t) {
    if (PyBool_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Invalid value for int32_t value");
        SWIG_fail;
    }
    int checkConvert = SWIG_AsVal_int($input, &$1);
    if (!SWIG_IsOK(checkConvert)) {
        PyErr_SetString(PyExc_ValueError, "Invalid value for int32_t value");
        SWIG_fail;
    }
}

/**
 * Support close method : Store.close()
 */
%typemap(in) GSBool allRelated{

    bool tmpBool;
    int checkConvert = 0;

    //input is boolean
    checkConvert = SWIG_AsVal_bool($input, &tmpBool);
    if (!SWIG_IsOK(checkConvert)) {
        PyErr_SetString(PyExc_ValueError, "Invalid value for bool value");
        SWIG_fail;
    }
    $1 = ((tmpBool == true) ? GS_TRUE : GS_FALSE);

}

%fragment("checkNullField", "header") {
static bool checkNullField(GSRow* row, int32_t rowField) {
    GSBool nullValue;
    GSResult ret;

    ret = gsGetRowFieldNull(row, (int32_t) rowField, &nullValue);
    if (ret != GS_RESULT_OK) {
        return false;
    }
    if (nullValue == GS_TRUE) {
        return true;
    }
    return false;
}
}

// Typemap for Container.put_rows()
%typemap(in, numinputs = 0) (GSRow** row, GSRowSet** rowSet) {
    GSRow* rowPtr;
    GSRowSet* rowSetPtr;
    $1 = &rowPtr;
    $2 = &rowSetPtr;
}

%feature("pythonappend") griddb::RowSet::fetch_rows(GSRow** row,
        GSRowSet** rowSet) %{
    #convert data from numpy.ndarray to pandas.DataFrame
    #"val" is output
    columnsList = self.get_column_names()
    val = pandas.DataFrame(val, columns = columnsList)
%}

%typemap(in, numinputs = 0) (bool* hasRow) {
    bool hasNextRowTmp = true;
    $1 = &hasNextRowTmp;
}

%typemap(argout, fragment = "getRowFields") (bool* hasRow) {
    bool retVal;
    int errorColumn;
    if (*$1 == false) {
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }
    GSRow* row = arg1->get_gsrow_ptr();
    PyObject *outList = PyList_New(arg1->get_column_count());
    if (outList == NULL) {
        PyErr_SetString(PyExc_ValueError, "Memory allocation for row is error");
        SWIG_fail;
    }
    GSType errorType;
    retVal = getRowFields(row, arg1->get_column_count(), arg1->get_gstype_list(),
        arg1->get_timestamp_to_float(), &errorColumn, &errorType, outList);
    if (retVal == false) {
        const int SIZE = 60;
        char errorMsg[SIZE];
        sprintf(errorMsg, "Can't get data for field %d with type %d", errorColumn,
            errorType);
        PyErr_SetString(PyExc_ValueError, errorMsg);
        SWIG_fail;
    }
    $result = outList;
}

// Typemap for Container.put_rows()
%feature("pythonprepend")
        griddb::Container::put_rows(GSRow** listRow, int rowCount) %{
    # listRow is input
    if isinstance(listRow, pandas.DataFrame) != True:
        raise Exception('Input should be DataFrame')
    # Convert to numpy ndarray
    listRow = listRow.to_numpy()
%}

%typemap(in, numinputs = 1, fragment ="cleanString",
        fragment = "convertToFieldWithType") (GSRow** listRow, int rowCount) {
    $1 = NULL;
    if (PyArray_API == NULL) {
        import_array();
    }
    if (!PyArray_Check($input)) {
        PyErr_SetString(PyExc_ValueError, "Input should be numpy.ndarray");
        SWIG_fail;
    }
    PyArrayObject* array = (PyArrayObject*) PyArray_EnsureArray($input);

    npy_intp* dim = PyArray_DIMS(array);
    $2 = dim[0];  // number of rows

    if ($2) {
        GSType* fieldTypes = arg1->getGSTypeList();
        try {
            $1 = new GSRow*[$2]();
        } catch (bad_alloc& ba) {
            PyErr_SetString(PyExc_ValueError, "Memory allocation error");
            SWIG_fail;
        }
        int length = dim[1];
        GSType type;
        int columnNumber = arg1->getColumnCount();
        if (length != columnNumber) {
            PyErr_SetString(PyExc_ValueError,
                    "num row is different with container info");
            SWIG_fail;
        }

        GSResult ret;
        GSContainer *mContainer = arg1->getGSContainerPtr();

        PyArrayIterObject* arrayInter =
                (PyArrayIterObject*)PyArray_IterNew((PyObject*)array);
        int rowCountVal = 0;  // Avoid confuse with input "int rowCount"
        int columnCount = 0;
        int count = 0;
        int alloc = 0;
        size_t size = 0;
        int res;
        PyObject* rowFieldPyObject;
        GSChar* stringVal;

        for (int i = 0; i < $2; i++) {
            ret = gsCreateRowByContainer(mContainer, &$1[i]);
            if (!GS_SUCCEEDED(ret)) {
                PyErr_SetString(PyExc_ValueError, "Can't create row");
                SWIG_fail;
            }
        }

        GSType* typeList = arg1->getGSTypeList();
        bool checkConvert;
        while (PyArray_ITER_NOTDONE(arrayInter)) {
            // Get data from numpy C array
            rowFieldPyObject = PyArray_GETITEM((const PyArrayObject*)array,
                    (char*)PyArray_ITER_DATA(arrayInter));
            // Convert to C type
            checkConvert = convertToFieldWithType($1[rowCountVal],
                    columnCount, rowFieldPyObject, typeList[columnCount]);
            if (!checkConvert) {
                const int SIZE = 60;
                char errorMsg[SIZE];
                sprintf(errorMsg, "Can't set data for field %d with type %d",
                        columnCount, typeList[columnCount]);
                PyErr_SetString(PyExc_ValueError, errorMsg);
                Py_DECREF(arrayInter);
                SWIG_fail;
            }

            // Update rowCountVal, columnCount and count++
            count++;
            if (count % length == 0 && rowCountVal < $2) {
                // New row data for GSRow
                rowCountVal++;
                columnCount = 0;
            } else if (columnCount < length && rowCountVal < $2) {
                // Still old row
                columnCount++;
            }
             // Get next data
            PyArray_ITER_NEXT(arrayInter);
        }

        Py_DECREF(arrayInter);
    }
}

%typemap(freearg) (GSRow** listRow, int rowCount) {
    if ($1) {
        for (int i = 0; i < $2; i++) {
            if ($1[i]) {
                gsCloseRow(&$1[i]);
            }
        }
        delete [] $1;
    }
}
