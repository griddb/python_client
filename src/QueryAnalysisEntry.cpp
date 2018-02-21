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

#include "QueryAnalysisEntry.h"

namespace griddb {
QueryAnalysisEntry::QueryAnalysisEntry(GSQueryAnalysisEntry* queryAnalysis) :
	mQueryAnalysis(NULL) {
	if (queryAnalysis) {
		mQueryAnalysis = (GSQueryAnalysisEntry*) malloc(sizeof(GSQueryAnalysisEntry));
		//Copy value which queryAnalysis point to
		*mQueryAnalysis = *queryAnalysis;
	}
}

QueryAnalysisEntry::~QueryAnalysisEntry() {
	if (mQueryAnalysis) {
		free((void *) mQueryAnalysis);
		mQueryAnalysis = NULL;
	}
}

void QueryAnalysisEntry::get(GSQueryAnalysisEntry* queryAnalysis) {
	queryAnalysis->id = mQueryAnalysis->id;
	queryAnalysis->depth = mQueryAnalysis->depth;
	queryAnalysis->type = mQueryAnalysis->type;
	queryAnalysis->valueType = mQueryAnalysis->valueType;
	queryAnalysis->value = mQueryAnalysis->value;
	queryAnalysis->statement = mQueryAnalysis->statement;
}
}
