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

#ifndef _ROW_H_
#define _ROW_H_

#include "gridstore.h"
#include <iostream>

using namespace std;

namespace griddb {

struct Field {
    GSChar *name;
    GSType type;
    GSValue value;
    Field() : name(NULL), type(GS_TYPE_STRING) {
        value.asString = NULL;
        value.asBlob.data = NULL;
    	value.asGeometry = NULL;
#if GS_COMPATIBILITY_VALUE_1_1_106
        value.asBoolArray.elements = NULL;
        value.asStringArray.elements = NULL;
        value.asByteArray.elements = NULL;
        value.asShortArray.elements = NULL;
        value.asIntegerArray.elements = NULL;
        value.asTimestampArray.elements = NULL;
        value.asLongArray.elements = NULL;
        value.asDoubleArray.elements = NULL;
#else
        value.asArray.elements.asBool = NULL;
        value.asArray.elements.asString = NULL;
        value.asArray.elements.asByte = NULL;
        value.asArray.elements.asShort = NULL;
        value.asArray.elements.asInteger = NULL;
        value.asArray.elements.asTimestamp = NULL;
        value.asArray.elements.asLong = NULL;
        value.asArray.elements.asDouble = NULL;
#endif
    };
};

class Row {
    Field* mFields;
    int mCount;
    GSRow* mRow;
public:
    Row(int size = 0, GSRow* gsRow = NULL);
    ~Row();
    void set_from_row(GSRow* row);
    void set_for_row(GSRow* row, GSContainerInfo* containerInfo = NULL);
    Field* get_field_ptr();
    int get_count();
    void resize(int size);

private:
    void set_for_field(GSRow* row, int no);
    void get_from_field(GSRow* row, int no, GSType type);
    void del_array_field();
};
}

#endif /* _ROW_H_ */
