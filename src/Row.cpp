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

#include "Row.h"
#include "GSException.h"
#include "ContainerInfo.h"

namespace griddb {

    Row::Row(int size, GSRow* gsRow) : mFields(NULL), mCount(size), mRow(gsRow) {
        if (size > 0) {
            resize(size);
        }
        else mCount = 0;
    }
    Row::~Row() {
        del_array_field();
        //gsCloseRow(&mRow);
    }
    /**
    * Set for field from GSRow.
    */
    void Row::del_array_field() {
        if (mFields) {
            for (int i = 0; i < mCount; i++) {
                switch (mFields[i].type){
                case GS_TYPE_STRING:
                    if (mFields[i].value.asString) {
                        free(const_cast<GSChar*>(mFields[i].value.asString));
                        mFields[i].value.asString = NULL;
                    }
                    break;
                case GS_TYPE_BLOB:
                    if (mFields[i].value.asBlob.data) {
                        free(const_cast<void*>(mFields[i].value.asBlob.data));
                        mFields[i].value.asBlob.data = NULL;
                    }
                    break;
                case GS_TYPE_GEOMETRY:
                    if (mFields[i].value.asGeometry) {
                        free(const_cast<GSChar*>(mFields[i].value.asGeometry));
                        mFields[i].value.asGeometry = NULL;
                    }
                    break;
                case GS_TYPE_INTEGER_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asIntegerArray.elements) {
                        free(const_cast<int32_t*> (mFields[i].value.asIntegerArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asInteger) {
                        free(const_cast<int32_t*> (mFields[i].value.asArray.elements.asInteger));
                    }
#endif
                    break;
                case GS_TYPE_STRING_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asStringArray.elements) {
                        for (int j = 0; j < mFields[i].value.asStringArray.size; j++) {
                            if (mFields[i].value.asStringArray.elements[j]) {
                                free(const_cast<GSChar*> (mFields[i].value.asStringArray.elements[j]));
                            }
                        }
                        free(const_cast<GSChar**> (mFields[i].value.asStringArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asString) {
                        for (int j = 0; j < mFields[i].value.asArray.length; j++) {
                            if (mFields[i].value.asArray.elements.asString[j]) {
                                free(const_cast<GSChar*> (mFields[i].value.asArray.elements.asString[j]));
                            }
                        }
                        free(const_cast<GSChar**> (mFields[i].value.asArray.elements.asString));
                    }
#endif
                    break;
                case GS_TYPE_BOOL_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asBoolArray.elements) {
                        free(const_cast<GSBool*> (mFields[i].value.asBoolArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asBool) {
                        free(const_cast<GSBool*> (mFields[i].value.asArray.elements.asBool));
                    }
#endif
                    break;
                case GS_TYPE_BYTE_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asByteArray.elements) {
                        free(const_cast<int8_t*> (mFields[i].value.asByteArray.elements));
                        mFields[i].value.asByteArray.elements = NULL;
                    }
#else
                    if (mFields[i].value.asArray.elements.asByte) {
                        free(const_cast<int8_t*> (mFields[i].value.asArray.elements.asByte));
                        mFields[i].value.asArray.elements.asByte = NULL;
                    }
#endif
                    break;
                case GS_TYPE_SHORT_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asShortArray.elements) {
                        free(const_cast<int16_t*> (mFields[i].value.asShortArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asShort) {
                        free(const_cast<int16_t*> (mFields[i].value.asArray.elements.asShort));
                    }
#endif
                    break;
                case GS_TYPE_LONG_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asLongArray.elements) {
                        free(const_cast<int64_t*> (mFields[i].value.asLongArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asLong) {
                        free(const_cast<int64_t*> (mFields[i].value.asArray.elements.asLong));
                    }
#endif
                    break;
                case GS_TYPE_FLOAT_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asFloatArray.elements) {
                        free(const_cast<float*> (mFields[i].value.asFloatArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asFloat) {
                        free(const_cast<float*> (mFields[i].value.asArray.elements.asFloat));
                    }
#endif
                    break;
                case GS_TYPE_DOUBLE_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asDoubleArray.elements) {
                        free(const_cast<double*> (mFields[i].value.asDoubleArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asDouble) {
                        free(const_cast<double*> (mFields[i].value.asArray.elements.asDouble));
                    }
#endif
                    break;
                case GS_TYPE_TIMESTAMP_ARRAY:
#if GS_COMPATIBILITY_VALUE_1_1_106
                    if (mFields[i].value.asTimestampArray.elements) {
                        free(const_cast<GSTimestamp*> (mFields[i].value.asTimestampArray.elements));
                    }
#else
                    if (mFields[i].value.asArray.elements.asTimestamp) {
                        free(const_cast<GSTimestamp*> (mFields[i].value.asArray.elements.asTimestamp));
                    }
#endif
                    break;
                }
            }
            delete [] mFields;
            mFields = NULL;
        }
    }
    /**
     * Set for field from GSRow.
     */
    void Row::set_from_row(GSRow* row) {
        // Resize fields as columnCount
        GSContainerInfo containerInfo;
        GSResult ret = gsGetRowSchema(row, &containerInfo);
        if (ret != GS_RESULT_OK) {
            throw GSException(ret, "can not get row schema to get");
        }
        if (containerInfo.columnCount != mCount) {
            resize(containerInfo.columnCount);
        }

        // Read value from row to fields
        for (int i = 0; i < mCount; i++) {
            set_for_field(row, i);
        }
    }
    /**
     * Set for GSRow from Field
     */
    void Row::set_for_row(GSRow* row, GSContainerInfo* containerInfo) {
        if (containerInfo) {
            if (containerInfo->columnCount != mCount) {
                throw GSException("column number is not match");
            }
            for (int i = 0; i < mCount; i++) {
                get_from_field(row, i, containerInfo->columnInfoList[i].type);
            }
        } else {
            GSContainerInfo containerInfo;
            GSResult ret = gsGetRowSchema(row, &containerInfo);
            if (ret != GS_RESULT_OK) {
                throw GSException(ret, "can not get row schema to set");
            }
            if (containerInfo.columnCount != mCount) {
                throw GSException("column number is not match");
            }
            for (int i = 0; i < mCount; i++) {
                get_from_field(row, i, containerInfo.columnInfoList[i].type);
            }
        }
    }
    void Row::resize(int size) {
        if (mFields) {
            del_array_field();
        }
        mFields = new Field[size];
        //memset(mFields, 0x0, sizeof(Field) * size);
        mCount = size;
    }
    Field* Row::get_field_ptr() {
        return mFields;
    }

    int Row::get_count() {
        return mCount;
    }

    void Row::set_for_field(GSRow* row, int no) {
        Field* field = &mFields[no];
        GSBool nullValue = GS_TRUE;
        GSResult ret;

        ret = gsGetRowFieldGeneral(row, no, &field->value, &field->type);
        if (ret != GS_RESULT_OK) {
            throw GSException(ret, "can not set for field");
        }
        GSChar *tmp;

        switch (field->type) {
        case GS_TYPE_STRING:
            tmp = strdup(field->value.asString);
            field->value.asString = tmp;
            break;
        case GS_TYPE_BLOB:
            tmp = (GSChar *) malloc(sizeof(GSChar*) * field->value.asBlob.size);
            memset(tmp, 0x0, field->value.asBlob.size);
            memcpy(tmp, field->value.asBlob.data, field->value.asBlob.size);
            field->value.asBlob.data = tmp;
            break;
        case GS_TYPE_GEOMETRY:
            tmp = strdup(field->value.asGeometry);
            field->value.asGeometry = tmp;
            break;
        case GS_TYPE_INTEGER_ARRAY:
            int32_t* tmpIntArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpIntArr = (int32_t *) malloc(sizeof(int32_t) * field->value.asIntegerArray.size);
            memset(tmpIntArr, 0x0, sizeof(int32_t) * field->value.asIntegerArray.size);
            memcpy(tmpIntArr, field->value.asIntegerArray.elements, sizeof(int32_t) * field.value.asIntegerArray.size);
            field->value.asIntegerArray.elements = tmpIntArr;
#else
            tmpIntArr = (int32_t *) malloc(
                    sizeof(int32_t) * field->value.asArray.length);
            memset(tmpIntArr, 0x0, sizeof(int32_t) * field->value.asArray.length);
            memcpy(tmpIntArr, field->value.asArray.elements.asInteger,
                    sizeof(int32_t) * field->value.asArray.length);
            field->value.asArray.elements.asInteger = tmpIntArr;
#endif
            break;
        case GS_TYPE_STRING_ARRAY:
            GSChar** tmpArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpArr = (GSChar**) malloc(sizeof(GSChar*) * field->value.asStringArray.size);
            for(int j = 0; j < field->value.asStringArray.size; j++) {
                tmpArr[j] = strdup(field->value.asStringArray.elements[j]);
            }
            field->value.asStringArray.elements = tmpArr;
#else
            tmpArr = (GSChar**) malloc(sizeof(GSChar*) * field->value.asArray.length);
            for(int j = 0; j < field->value.asArray.length; j++) {
                tmpArr[j] = strdup(field->value.asArray.elements.asString[j]);
            }
            field->value.asArray.elements.asString = tmpArr;
#endif
            break;
        case GS_TYPE_BOOL_ARRAY:
            GSBool* tmpBoolArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpBoolArr = (GSBool*) malloc(sizeof(GSBool) * field->value.asBoolArray.size);
            memset(tmpBoolArr, 0x0, sizeof(GSBool) * field->value.asBoolArray.size);
            memcpy(tmpBoolArr, field->value.asBoolArray.elements, sizeof(GSBool) * field.value.asBoolArray.size);
            field->value.asBoolArray.elements = tmpBoolArr;
#else
            tmpBoolArr = (GSBool*) malloc(sizeof(GSBool) * field->value.asArray.length);
            memset(tmpBoolArr, 0x0, sizeof(GSBool) * field->value.asArray.length);
            memcpy(tmpBoolArr, field->value.asArray.elements.asBool,
                    sizeof(GSBool) * field->value.asArray.length);
            field->value.asArray.elements.asBool = tmpBoolArr;
#endif
            break;
        case GS_TYPE_BYTE_ARRAY:
            int8_t* tmpByteArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpByteArr = (int8_t*) malloc(sizeof(int8_t) * field->value.asByteArray.size);
            memset(tmpByteArr, 0x0, sizeof(int8_t) * field->value.asByteArray.size);
            memcpy(tmpByteArr, field->value.asByteArray.elements, sizeof(int8_t) * field.value.asByteArray.size);
            field->value.asByteArray.elements = tmpByteArr;
#else
            tmpByteArr = (int8_t*) malloc(sizeof(int8_t) * field->value.asArray.length);
            memset(tmpByteArr, 0x0, sizeof(int8_t) * field->value.asArray.length);
            memcpy(tmpByteArr, field->value.asArray.elements.asByte,
                    sizeof(int8_t) * field->value.asArray.length);
            field->value.asArray.elements.asByte = tmpByteArr;
#endif
            break;
        case GS_TYPE_SHORT_ARRAY:
            int16_t* tmpShortArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpShortArr = (int16_t*) malloc(sizeof(int16_t) * field->value.asShortArray.size);
            memset(tmpShortArr, 0x0, sizeof(int16_t) * field->value.asShortArray.size);
            memcpy(tmpShortArr, field->value.asShortArray.elements, sizeof(int16_t) * field.value.asShortArray.size);
            field->value.asShortArray.elements = tmpShortArr;
#else
            tmpShortArr = (int16_t*) malloc(sizeof(int16_t) * field->value.asArray.length);
            memset(tmpShortArr, 0x0, sizeof(int16_t) * field->value.asArray.length);
            memcpy(tmpShortArr, field->value.asArray.elements.asShort,
                    sizeof(int16_t) * field->value.asArray.length);
            field->value.asArray.elements.asShort = tmpShortArr;
#endif
            break;
        case GS_TYPE_LONG_ARRAY:
            int64_t* tmpLongArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpLongArr = (int64_t*) malloc(sizeof(int64_t) * field->value.asLongArray.size);
            memset(tmpLongArr, 0x0, sizeof(int64_t) * field->value.asLongArray.size);
            memcpy(tmpLongArr, field->value.asLongArray.elements, sizeof(int64_t) * field.value.asLongArray.size);
            field->value.asShortArray.elements = tmpLongArr;
#else
            tmpLongArr = (int64_t*) malloc(sizeof(int64_t) * field->value.asArray.length);
            memset(tmpLongArr, 0x0, sizeof(int64_t) * field->value.asArray.length);
            memcpy(tmpLongArr, field->value.asArray.elements.asLong,
                    sizeof(int64_t) * field->value.asArray.length);
            field->value.asArray.elements.asLong = tmpLongArr;
#endif
            break;
        case GS_TYPE_FLOAT_ARRAY:
            float* tmpFloatArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpFloatArr = (float*) malloc(sizeof(float) * field->value.asFloatArray.size);
            memset(tmpFloatArr, 0x0, sizeof(float) * field->value.asFloatArray.size);
            memcpy(tmpFloatArr, field->value.asFloatArray.elements, sizeof(float) * field.value.asFloatArray.size);
            field->value.asFloatArray.elements = tmpFloatArr;
#else
            tmpFloatArr = (float*) malloc(sizeof(float) * field->value.asArray.length);
            memset(tmpFloatArr, 0x0, sizeof(float) * field->value.asArray.length);
            memcpy(tmpFloatArr, field->value.asArray.elements.asFloat,
                    sizeof(float) * field->value.asArray.length);
            field->value.asArray.elements.asFloat = tmpFloatArr;
#endif
            break;
        case GS_TYPE_DOUBLE_ARRAY:
            double* tmpDoubleArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpDoubleArr = (double*) malloc(sizeof(double) * field->value.asDoubleArray.size);
            memset(tmpDoubleArr, 0x0, sizeof(double) * field->value.asDoubleArray.size);
            memcpy(tmpDoubleArr, field->value.asDoubleArray.elements, sizeof(double) * field.value.asDoubleArray.size);
            field->value.asDoubleArray.elements = tmpDoubleArr;
#else
            tmpDoubleArr = (double*) malloc(sizeof(double) * field->value.asArray.length);
            memset(tmpDoubleArr, 0x0, sizeof(double) * field->value.asArray.length);
            memcpy(tmpDoubleArr, field->value.asArray.elements.asDouble,
                    sizeof(double) * field->value.asArray.length);
            field->value.asArray.elements.asDouble = tmpDoubleArr;
#endif
            break;
        case GS_TYPE_TIMESTAMP_ARRAY:
            GSTimestamp* tmpTimestampArr;
#if GS_COMPATIBILITY_VALUE_1_1_106
            tmpTimestampArr = (GSTimestamp*) malloc(sizeof(GSTimestamp) * field->value.asTimestampArray.size);
            memset(tmpTimestampArr, 0x0, sizeof(GSTimestamp) * field->value.asTimestampArray.size);
            memcpy(tmpTimestampArr, field->value.asTimestampArray.elements, sizeof(GSTimestamp) * field.value.asTimestampArray.size);
            field->value.asTimestampArray.elements = tmpTimestampArr;
#else
            tmpTimestampArr = (GSTimestamp*) malloc(sizeof(GSTimestamp) * field->value.asArray.length);
            memset(tmpTimestampArr, 0x0, sizeof(GSTimestamp) * field->value.asArray.length);
            memcpy(tmpTimestampArr, field->value.asArray.elements.asTimestamp,
                    sizeof(GSTimestamp) * field->value.asArray.length);
            field->value.asArray.elements.asTimestamp = tmpTimestampArr;
#endif
            break;
        }
    }

    void Row::get_from_field(GSRow* row, int no, GSType type) {
        GSResult ret;
        Field* field = &mFields[no];
        GSValue fieldValue;
        switch (type) {
        case GS_TYPE_BLOB:
            if(field->type == GS_TYPE_BLOB) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_BLOB);
            } else if(field->type == GS_TYPE_STRING) {
                fieldValue.asBlob.size = strlen(field->value.asString);
                fieldValue.asBlob.data = field->value.asString;
                ret = gsSetRowFieldGeneral(row, no, &fieldValue, GS_TYPE_BLOB);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for blob");
            }
            break;
        case GS_TYPE_BOOL:
#if GS_COMPATIBILITY_SUPPORT_3_5
            if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
            } else
#endif
            if (field->type == GS_TYPE_BOOL) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_BOOL);
            } else {
                throw GSException("incorrect column type to set for bool");
            }
            break;
        case GS_TYPE_INTEGER:
            if (field->type == GS_TYPE_BYTE) {
                field->value.asInteger = field->value.asByte;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_INTEGER);
            } else if (field->type == GS_TYPE_SHORT) {
                field->value.asInteger = field->value.asShort;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_INTEGER);
            } else if(field->type == GS_TYPE_INTEGER) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_INTEGER);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for integer");
            }
            break;
        case GS_TYPE_LONG:
            if(field->type == GS_TYPE_LONG) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_LONG);
            } else if (field->type == GS_TYPE_BYTE) {
                field->value.asLong = field->value.asByte;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_LONG);
            } else if (field->type == GS_TYPE_SHORT) {
                field->value.asLong = field->value.asShort;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_LONG);
            } else if(field->type == GS_TYPE_INTEGER) {
                field->value.asLong = field->value.asInteger;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_LONG);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for long");
            }
            break;
        case GS_TYPE_FLOAT:
            if(field->type == GS_TYPE_FLOAT) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_FLOAT);
            } else if (field->type == GS_TYPE_BYTE) {
                field->value.asFloat = field->value.asByte;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_FLOAT);
            } else if (field->type == GS_TYPE_SHORT) {
                field->value.asFloat = field->value.asShort;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_FLOAT);
            } else if(field->type == GS_TYPE_INTEGER) {
                field->value.asFloat = field->value.asInteger;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_FLOAT);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for float");
            }
            break;
        case GS_TYPE_DOUBLE:
            if(field->type == GS_TYPE_DOUBLE) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_DOUBLE);
            } else if(field->type == GS_TYPE_FLOAT) {
                field->value.asDouble = field->value.asFloat;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_DOUBLE);
            } else if (field->type == GS_TYPE_BYTE) {
                field->value.asDouble = field->value.asByte;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_DOUBLE);
            } else if (field->type == GS_TYPE_SHORT) {
                field->value.asDouble = field->value.asShort;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_DOUBLE);
            } else if(field->type == GS_TYPE_INTEGER) {
                field->value.asDouble = field->value.asInteger;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_DOUBLE);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for double");
            }
            break;
        case GS_TYPE_STRING:
#if GS_COMPATIBILITY_SUPPORT_3_5
            if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
            } else
#endif
                if (field->type == GS_TYPE_STRING) {
                    ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_STRING);
                } else {
                    throw GSException("incorrect column type to set for string");
                }
            break;
        case GS_TYPE_TIMESTAMP:
            if (field->type == GS_TYPE_TIMESTAMP) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_TIMESTAMP);
            }
#if GS_COMPATIBILITY_SUPPORT_3_5
            else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
            }
#endif
            else {
                throw GSException("incorrect column type to set for timestamp");
            }
            break;
        case GS_TYPE_SHORT:
            if(field->type == GS_TYPE_SHORT) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_SHORT);
            } else if(field->type == GS_TYPE_BYTE) {
                field->value.asShort = field->value.asByte;
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_SHORT);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for short");
            }
            break;
        case GS_TYPE_BYTE:
            if(field->type == GS_TYPE_BYTE) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_BYTE);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for byte");
            }
            break;
        case GS_TYPE_GEOMETRY:
            if (field->type == GS_TYPE_GEOMETRY) {
                ret = gsSetRowFieldGeneral(row, no, &field->value, GS_TYPE_GEOMETRY);
#if GS_COMPATIBILITY_SUPPORT_3_5
            } else if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
#endif
            } else {
                throw GSException("incorrect column type to set for geometry");
            }
            break;
        case GS_TYPE_INTEGER_ARRAY:
        case GS_TYPE_STRING_ARRAY:
        case GS_TYPE_BOOL_ARRAY:
        case GS_TYPE_BYTE_ARRAY:
        case GS_TYPE_SHORT_ARRAY:
        case GS_TYPE_LONG_ARRAY:
        case GS_TYPE_FLOAT_ARRAY:
        case GS_TYPE_DOUBLE_ARRAY:
        case GS_TYPE_TIMESTAMP_ARRAY:
#if GS_COMPATIBILITY_SUPPORT_3_5
            if (field->type == GS_TYPE_NULL) {
                ret = gsSetRowFieldNull(row, no);
            } else {
#endif
                ret = gsSetRowFieldGeneral(row, no, &(field->value), type);
#if GS_COMPATIBILITY_SUPPORT_3_5
            }
#endif
            break;
        default:
            throw GSException("No type to support for getting field");
            break;
        }

        if (ret != GS_RESULT_OK) {
            throw GSException("Can not set value for row field");
        }
    }

}
