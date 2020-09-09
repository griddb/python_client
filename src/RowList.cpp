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

#include "RowList.h"

namespace griddb {

    RowList::RowList(GSRow *gsRow, GSRowSet *gsRowSet, GSType *typelist,
            int columnCount, bool timetampFloat) :
            mRowSet(gsRowSet), mRow(gsRow), mTypelist(typelist),
            mColumnCount(columnCount), mTimetampFloat(timetampFloat) {
    }

    /**
     * Support iterator object.
     */
    RowList* RowList::__iter__() {
        return this;
    }

    /**
     * Support iterator object: get next row
     */
    void RowList::__next__(bool* hasRow) {
        *hasRow = gsHasNextRow(mRowSet);
        if (*hasRow) {
            gsGetNextRow(mRowSet, mRow);
        }
    }

    /**
     * Refer GSRow pointer from RowSet
     */
    GSRow* RowList::get_gsrow_ptr() {
        return this->mRow;
    }

    /**
     * Refer GSType pointer from RowSet
     */
    GSType* RowList::get_gstype_list() {
        return mTypelist;
    }

    /**
     * Refer number column from RowSet
     */
    int RowList::get_column_count() {
        return mColumnCount;
    }

    /**
     * Refer number column from RowSet
     */
    bool RowList::get_timestamp_to_float() {
        return mTimetampFloat;
    }

}  // namespace griddb
