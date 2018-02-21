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
		gsCloseRow(&mRow);
	}

	/**
	* Set for field from GSRow.
	*/
	void Row::del_array_field() {
		if (mFields) {
			for(int i = 0; i < mCount; i++) {
				if(mFields[i].type == GS_TYPE_STRING) {
					if(mFields[i].value.asString) {
						free(const_cast<GSChar*>(mFields[i].value.asString));
						mFields[i].value.asString = NULL;
					}
				}
				if(mFields[i].type == GS_TYPE_BLOB) {
					if(mFields[i].value.asBlob.data) {
						free(const_cast<void*>(mFields[i].value.asBlob.data));
						mFields[i].value.asBlob.data = NULL;
					}
				}
			}
			delete [] mFields;
		}
	}

	/**
	 * Set for field from GSRow.
	 */
	void Row::set_from_row(GSRow* row) {
		// Resize fields as columnCount
		GSContainerInfo containerInfo;
		GSResult ret = gsGetRowSchema(row, &containerInfo);
		if(ret != GS_RESULT_OK) {
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
	void Row::set_for_row(GSRow* row) {
		GSContainerInfo containerInfo;
		GSResult ret = gsGetRowSchema(row, &containerInfo);
		if(ret != GS_RESULT_OK) {
			throw GSException(ret, "can not get row schema to set");
		}
		if (containerInfo.columnCount != mCount) {
			throw GSException("column number is not match");
		}
		for (int i = 0; i < mCount; i++) {
			get_from_field(row, i, containerInfo.columnInfoList[i].type);
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
		GSBool nullValue = 0;
		GSResult ret;

		ret = gsGetRowFieldGeneral(row, no, &field->value, &field->type);
		if(ret != GS_RESULT_OK) {
			throw GSException(ret, "can not set for field");
		}
#if GS_COMPATIBILITY_SUPPORT_3_5
		if (field->type == GS_TYPE_NULL) {
			ret = gsGetRowFieldNull(row, no, &nullValue);
			if(ret != GS_RESULT_OK) {
				throw GSException(ret, "can check null for column");
			}
			if (nullValue == 0) {
				//Type is GS_TYPE_NULL but value is not null
				throw GSException(ret, "can not set for field");
			}
		}
#endif
		if(field->type == GS_TYPE_STRING) {
			GSChar *tmp = (GSChar *)malloc(sizeof(GSChar*) * strlen(field->value.asString) + 1);
			memset(tmp, 0x0, sizeof(GSChar*) * strlen(field->value.asString) + 1);
			memcpy(tmp, field->value.asString, strlen(field->value.asString));
			field->value.asString = tmp;
		}
		if(field->type == GS_TYPE_BLOB) {
			GSChar *tmp = (GSChar *)malloc(sizeof(GSChar*) * field->value.asBlob.size + 1);
			memset(tmp, 0x0, field->value.asBlob.size + 1);
			memcpy(tmp, field->value.asBlob.data, field->value.asBlob.size);
			field->value.asBlob.data = tmp;
		}
	}

	void Row::get_from_field(GSRow* row, int no, GSType type) {
		GSResult ret;
		Field* field = &mFields[no];
		switch (type) {
		case GS_TYPE_BLOB:
			if(field->type == GS_TYPE_BLOB) {
				ret = gsSetRowFieldByBlob(row, no, &field->value.asBlob);
			} else if(field->type == GS_TYPE_STRING) {
				GSBlob tmpBlob;
				tmpBlob.size = strlen(field->value.asString);
				tmpBlob.data = field->value.asString;
				ret = gsSetRowFieldByBlob(row, no, &tmpBlob);
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif
			} else {
				throw GSException("incorrect column type to set for blob");
			}
			break;
		case GS_TYPE_BOOL:
#if GS_COMPATIBILITY_SUPPORT_3_5
			if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
			} else
#endif
			if(field->type == GS_TYPE_BOOL) {
				ret = gsSetRowFieldByBool(row, no, field->value.asBool);
			} else {
				throw GSException("incorrect column type to set for bool");
			}
			break;
		case GS_TYPE_INTEGER:
			if(field->type == GS_TYPE_LONG) {
				ret = gsSetRowFieldByInteger(row, no, static_cast<int32_t>(field->value.asLong));
			} else if(field->type == GS_TYPE_INTEGER) {
				ret = gsSetRowFieldByInteger(row, no, field->value.asInteger);
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif
			} else {
				throw GSException("incorrect column type to set for integer");
			}
			break;
		case GS_TYPE_LONG:
			if(field->type == GS_TYPE_LONG) {
				ret = gsSetRowFieldByLong(row, no, field->value.asLong);
			} else if(field->type == GS_TYPE_INTEGER) {
				ret = gsSetRowFieldByLong(row, no, field->value.asInteger);
			} else if(field->type == GS_TYPE_DOUBLE) {
				ret = gsSetRowFieldByLong(row, no, static_cast<long>(field->value.asDouble));
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif
			} else {
				throw GSException("incorrect column type to set for long");
			}
			break;
		case GS_TYPE_FLOAT:
			if(field->type == GS_TYPE_FLOAT) {
				ret = gsSetRowFieldByFloat(row, no, field->value.asFloat);
			} else if(field->type == GS_TYPE_DOUBLE) {
				ret = gsSetRowFieldByFloat(row, no, field->value.asDouble);
			} else if(field->type == GS_TYPE_INTEGER) {
				ret = gsSetRowFieldByLong(row, no, field->value.asInteger);
			} else if(field->type == GS_TYPE_LONG) {
				ret = gsSetRowFieldByFloat(row, no, field->value.asLong);
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif
			} else {
				throw GSException("incorrect column type to set for float");
			}
			break;
		case GS_TYPE_DOUBLE:
			if(field->type == GS_TYPE_DOUBLE) {
				ret = gsSetRowFieldByDouble(row, no, field->value.asDouble);
			} else if(field->type == GS_TYPE_FLOAT) {
				ret = gsSetRowFieldByDouble(row, no, field->value.asFloat);
			} else if(field->type == GS_TYPE_LONG) {
				ret = gsSetRowFieldByDouble(row, no, field->value.asLong);
			} else if(field->type == GS_TYPE_INTEGER) {
				ret = gsSetRowFieldByDouble(row, no, field->value.asInteger);
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif

			} else {
				throw GSException("incorrect column type to set for double");
			}
			break;
		case GS_TYPE_STRING:
#if GS_COMPATIBILITY_SUPPORT_3_5
			if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
			} else
#endif
			if(field->type == GS_TYPE_STRING) {
				ret = gsSetRowFieldByString(row, no, field->value.asString);
			} else {
				throw GSException("incorrect column type to set for string");
			}
			break;
		case GS_TYPE_TIMESTAMP:
#if GS_COMPATIBILITY_SUPPORT_3_5
			if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
			} else
#endif
			{
				ret = gsSetRowFieldByTimestamp(row, no, field->value.asTimestamp);
			}
			break;
		case GS_TYPE_SHORT:
			if(field->type == GS_TYPE_SHORT) {
				ret = gsSetRowFieldByShort(row, no, field->value.asShort);
			} else if(field->type == GS_TYPE_LONG) {
				ret = gsSetRowFieldByShort(row, no, field->value.asLong);
			} else if(field->type == GS_TYPE_INTEGER) {
				ret = gsSetRowFieldByShort(row, no, field->value.asInteger);
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif
			} else {
				throw GSException("incorrect column type to set for short");
			}
			break;
		case GS_TYPE_BYTE:
			if(field->type == GS_TYPE_BYTE) {
				ret = gsSetRowFieldByByte(row, no, field->value.asByte);
			} else if(field->type == GS_TYPE_LONG) {
				ret = gsSetRowFieldByByte(row, no, field->value.asLong);
			} else if(field->type == GS_TYPE_INTEGER) {
				ret = gsSetRowFieldByByte(row, no, field->value.asInteger);
#if GS_COMPATIBILITY_SUPPORT_3_5
			} else if(field->type == GS_TYPE_NULL) {
				ret =  gsSetRowFieldNull(row, no);
#endif
			} else {
				throw GSException("incorrect column type to set for byte");
			}
			break;
		default:
			throw GSException("No type to support for getting field");
			break;
		}
		if (ret != GS_RESULT_OK) {
			throw GSException(ret, "error set for row");
		}
	}

}
