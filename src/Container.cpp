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

#include "Container.h"
#include "GSException.h"

namespace griddb {

	Container::Container(GSContainer *container) : mContainer(container), mRow(NULL), typeList(NULL), columnCount(0) {
		GSResult ret;
		if((ret = gsCreateRowByContainer(mContainer, &mRow)) != GS_RESULT_OK) {
			throw GSException(ret, "can not create row from Container");
		}
		ret = gsGetRowSchema(mRow, &mContainerInfo);
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	Container::Container(GSContainer *container, GSContainerInfo containerInfo) : mContainer(container),
			mContainerInfo(containerInfo), mRow(NULL), typeList(NULL), columnCount(0) {
		GSResult ret;
		GSRow* row;
		if((ret = gsCreateRowByContainer(mContainer, &mRow)) != GS_RESULT_OK) {
			throw GSException(ret, "can not create row from Container");
		}
	}


	Container::~Container() {
	// allRelated = FALSE, since all row object is managed by Row class
		close(GS_FALSE);
		gsCloseRow(&mRow);
	}

	/**
	 * Close container.
	 */
	void Container::close(GSBool allRelated) {
		//Release container and all related resources
		if(mContainer != NULL) {
			gsCloseContainer(&mContainer, allRelated);
			mContainer = NULL;
			free(typeList);
		}
	}

	/**
	 * Removes the specified type of index among indexes on the specified Column.
	 */
	void Container::drop_index(const char* columnName, GSIndexTypeFlags indexType, const char *name) {
		GSResult ret = GS_RESULT_OK;
#if GS_COMPATIBILITY_SUPPORT_3_5
		if (name) {
			int colIndex = 0;
			for (int i = 0; i < mContainerInfo.columnCount; i++) {
				if (strcmp(mContainerInfo.columnInfoList[i].name, columnName) == 0) {
					colIndex = i;
					break;
				}
			}
			GSIndexInfo indexInfo = {name, indexType, colIndex, columnName};
			ret = gsDropIndexDetail(mContainer, &indexInfo);
		}
		else {
			ret = gsDropIndex(mContainer, columnName, indexType);
		}
#else
		ret = gsDropIndex(mContainer, columnName, indexType);
#endif
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	/*
	 * Creates a specified type of index on the specified Column.
	 */
	void Container::create_index(const char *columnName, GSIndexTypeFlags indexType, const char *name) {
		GSResult ret = GS_RESULT_OK;
#if GS_COMPATIBILITY_SUPPORT_3_5
		if (name){
			int colIndex = 0;
			for (int i = 0; i < mContainerInfo.columnCount; i++) {
				if (strcmp(mContainerInfo.columnInfoList[i].name, columnName) == 0) {
					colIndex = i;
					break;
				}
			}
			GSIndexInfo indexInfo = {name, indexType, colIndex, columnName};
			ret = gsCreateIndexDetail(mContainer, &indexInfo);
		}
		else {
			ret = gsCreateIndex(mContainer, columnName, indexType);
		}
#else
			ret = gsCreateIndex(mContainer, columnName, indexType);
#endif
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	/**
	 * Writes the results of earlier updates to a non-volatile storage medium, such as SSD, so as to prevent the data from being lost even if all cluster nodes stop suddenly.
	 */
	void Container::flush() {
		GSResult ret = gsFlush(mContainer);

		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	/**
	 * Put row to database.
	 */
	bool Container::put(Row *rowContainer) {
		GSBool bExists;
		rowContainer->set_for_row(mRow);
		GSResult ret = gsPutRow(mContainer, NULL, mRow, &bExists);
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}

		return bExists;
	}

	/**
	 * Get current container type
	 */
	GSContainerType Container::get_type() {
		GSContainerType containerType;
		GSResult ret = gsGetContainerType(mContainer, &containerType);

		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}

		return containerType;
	}

	/**
	 * Rolls back the result of the current transaction and starts a new transaction in the manual commit mode.
	 */
	void Container::abort() {
		GSResult ret = gsAbort(mContainer);

		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	/**
	 * Create query from input string.
	 */
	Query* Container::query(const char* query) {
		GSQuery *pQuery;
		gsQuery(mContainer, query, (&pQuery));

		GSRow *row = mRow;
		GSResult ret = gsGetRowSchema(mRow, &mContainerInfo);

		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}

		return new Query(pQuery, &mContainerInfo, mRow);
	}

	/**
	 * Set auto commit to true or false.
	 */
	void Container::set_auto_commit(bool enabled){
		GSBool gsEnabled;
		gsEnabled = (enabled == true ? GS_TRUE:GS_FALSE);
		gsSetAutoCommit(mContainer, gsEnabled);
	}

	/**
	 * Commit changes to database when autocommit is set to false.
	 */
	void Container::commit() {
		GSResult ret = gsCommit(mContainer);
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	/**
	 * Returns the content of a Row.
	 */
	GSBool Container::get(Field* keyFields, Row *rowdata) {
		GSBool exists;
		GSResult ret;
		void *key = NULL;
		if (!keyFields) {
			key = keyFields;
		} else if(keyFields->type == GS_TYPE_STRING) {
			key = &keyFields->value.asString;
		} else if(keyFields->type == GS_TYPE_INTEGER) {
			key = &keyFields->value.asInteger;
		} else if(keyFields->type == GS_TYPE_LONG) {
			key = &keyFields->value.asLong;
		} else if(keyFields->type == GS_TYPE_TIMESTAMP) {
			key = &keyFields->value.asTimestamp;
		}
		else {
			throw GSException(mContainer, "No found type of filed to get row");
		}
		ret = gsGetRow(mContainer, key, mRow, &exists);
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
		rowdata->set_from_row(mRow);
		return exists;
	}



	/*
	 * Deletes a Row corresponding to Row key
	 */
	bool Container::remove(Field* keyFields) {
		GSBool exists = GS_FALSE;
		GSResult ret;
		if (keyFields) {
			ret = gsDeleteRow(mContainer, &keyFields->value, &exists);
		} else {
			// Case null pointer
			ret = gsDeleteRow(mContainer, keyFields, &exists);
		}
		if(ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
		return (bool) exists;
	}

	/**
	 * Multiput data
	 */
	void Container::multi_put(Row** listRowdata, int rowCount) {
		GSResult ret;
		GSBool bExists;
		GSRow** rowObjs = (GSRow**) malloc(rowCount * sizeof(GSRow *));

		for (int i = 0; i < rowCount; i++) {
			GSRow *gsrow;
			gsCreateRowByContainer(mContainer, &gsrow);
			Row* tmpRow = listRowdata[i];
			tmpRow->set_for_row(gsrow);
			rowObjs[i] = gsrow;
		}

		//data for each container
		ret = gsPutMultipleRows(mContainer, (const void * const *) rowObjs,
				rowCount, &bExists);

		for (int rowNum = 0; rowNum < rowCount; rowNum++) {
			GSRow* gsRow = (GSRow *) rowObjs[rowNum];
			gsCloseRow(&gsRow);
		}

		free((void*) rowObjs);
		if (ret != GS_RESULT_OK) {
			throw GSException(mContainer, ret);
		}
	}

	/**
	 * Support Store::multi_put
	 */
	GSContainer* Container::getGSContainerPtr(){
		return mContainer;
	}
	
	GSType* Container::getGSTypeList(){
		if (typeList == NULL){
			GSResult ret = gsGetRowSchema(mRow, &mContainerInfo);
			typeList = (GSType*) malloc(sizeof(GSType) * mContainerInfo.columnCount);
			for (int i = 0; i < mContainerInfo.columnCount; i++){
				typeList[i] = mContainerInfo.columnInfoList[i].type;
			}
		}
		return typeList;
	}
	
	int Container::getColumnCount(){
		if (columnCount == 0){
			GSResult ret = gsGetRowSchema(mRow, &mContainerInfo);
			columnCount = mContainerInfo.columnCount;
		}
		return columnCount;
	}
}
