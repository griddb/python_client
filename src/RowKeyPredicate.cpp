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

#include "RowKeyPredicate.h"
#include "GSException.h"
#include <string.h>

namespace griddb {

    RowKeyPredicate::RowKeyPredicate(GSRowKeyPredicate *predicate, GSType type): mPredicate(predicate), mType(type),
            timestamp_output_with_float(false){
    }
    /**
     * Destructor. Call close methods to release resource
     */
    RowKeyPredicate::~RowKeyPredicate() {
        close();
    }
    /**
     * Convert from C-API: gsCloseRowKeyPredicate
     */
    void RowKeyPredicate::close() {
        if (mPredicate != NULL) {
            gsCloseRowKeyPredicate(&mPredicate);
            mPredicate = NULL;
        }
    }
//    /**
//     * Get finish key by string. Convert from C-API: gsSetPredicateFinishKeyByString
//     */
//    const GSChar* RowKeyPredicate::get_finish_key_as_string() {
//        GSChar *finishKey;
//        GSResult ret = gsGetPredicateFinishKeyAsString(mPredicate, (const GSChar **) &finishKey);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//        return finishKey;
//    }
//    /**
//     * Get finish key by int. Convert from C-API: gsGetPredicateFinishKeyAsInteger
//     */
//    int32_t RowKeyPredicate::get_finish_key_as_integer() {
//        int32_t* finishKeyPtr;
//        GSResult ret = gsGetPredicateFinishKeyAsInteger(mPredicate, (const int32_t **) &finishKeyPtr);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//        return *finishKeyPtr;
//    }
//    /**
//     * Get finish key by long. Convert from C-API: gsGetPredicateFinishKeyAsLong
//     */
//    int64_t RowKeyPredicate::get_finish_key_as_long() {
//        int64_t* finishKeyPtr;
//        GSResult ret = gsGetPredicateFinishKeyAsLong(mPredicate, (const int64_t **) &finishKeyPtr);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//        return *finishKeyPtr;
//    }
//    /**
//     * Get finish key by timestamp. Convert from C-API: gsGetPredicateFinishKeyAsTimestamp
//     */
//    GSTimestamp RowKeyPredicate::get_finish_key_as_timestamp() {
//        GSTimestamp* finishKeyPtr;
//        GSResult ret = gsGetPredicateFinishKeyAsTimestamp(mPredicate, (const GSTimestamp **) &finishKeyPtr);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//        return *finishKeyPtr;
//    }
//    /**
//     * Set finish key by string. Convert from C-API: gsSetPredicateFinishKeyByString
//     */
//    void RowKeyPredicate::set_finish_key_by_string(const GSChar* finishKey) {
//        GSResult ret = gsSetPredicateFinishKeyByString(mPredicate, finishKey);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Set finish key by integer. Convert from C-API: gsSetPredicateFinishKeyByInteger
//     */
//    void RowKeyPredicate::set_finish_key_by_integer(const int32_t finishKey) {
//        GSResult ret = gsSetPredicateFinishKeyByInteger(mPredicate, &finishKey);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Set finish key by long. Convert from C-API: gsSetPredicateFinishKeyByLong
//     */
//    void RowKeyPredicate::set_finish_key_by_long(const int64_t finishKey) {
//        GSResult ret = gsSetPredicateFinishKeyByLong(mPredicate, &finishKey);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Set finish key by timestamp. Convert from C-API: gsSetPredicateFinishKeyByTimestamp
//     */
//    void RowKeyPredicate::set_finish_key_by_timestamp(const GSTimestamp finishKey) {
//        GSResult ret = gsSetPredicateFinishKeyByTimestamp(mPredicate, &finishKey);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Add key by string. Convert from C-API: gsAddPredicateKeyByString
//     */
//    void RowKeyPredicate::add_key_by_string(const GSChar* key) {
//        GSResult ret = gsAddPredicateKeyByString(mPredicate, key);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Add key by integer. Convert from C-API: gsAddPredicateKeyByTimestamp
//     */
//    void RowKeyPredicate::add_key_by_integer(int32_t key) {
//        GSResult ret = gsAddPredicateKeyByInteger(mPredicate, key);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Add key by long. Convert from C-API: gsAddPredicateKeyByLong
//     */
//    void RowKeyPredicate::add_key_by_long(int64_t key) {
//        GSResult ret = gsAddPredicateKeyByLong(mPredicate, key);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//    }
    /**
     * Get key type. Convert from C-API: gsGetPredicateKeyType
     */
    GSType RowKeyPredicate::get_key_type() {
        return mType;
//        GSType key;
//        GSResult ret = gsGetPredicateKeyType(mPredicate, &key);
//        if (ret != GS_RESULT_OK) {
//            throw new GSException(mPredicate, ret);
//        }
//        return key;
    }
    /*
     * Returns the value of Row key at the start and end position of the range condition
     */
    void RowKeyPredicate::get_range(Field* startField, Field* finishField) {
        GSType key_type = get_key_type();
        startField->type = key_type;
        finishField->type = key_type;
        const GSValue *startKey;
        GSResult ret = gsGetPredicateStartKeyGeneral(mPredicate, &startKey);
        if (ret != GS_RESULT_OK) {
            throw GSException(mPredicate, ret);
        }
        startField->value = *startKey;
        const GSValue *endKey;
        ret = gsGetPredicateFinishKeyGeneral(mPredicate, &endKey);
        if (ret != GS_RESULT_OK) {
            throw GSException(mPredicate, ret);
        }
        finishField->value = *endKey;
    }
    /*
     * Sets the value of Row key as the start and end position of the range conditions
     */
    void RowKeyPredicate::set_range(Field* startKey, Field* finishKey) {
        GSType key_type = get_key_type();
        GSResult ret;

        switch (key_type) {
        case GS_TYPE_LONG:
            if (startKey->type == GS_TYPE_LONG) {
                ret = gsSetPredicateStartKeyByLong(mPredicate, (int64_t*)&startKey->value.asLong);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }

                ret = gsSetPredicateFinishKeyByLong(mPredicate,
                        (int64_t *) &finishKey->value.asLong);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else if (startKey->type == GS_TYPE_INTEGER) {
                ret = gsSetPredicateStartKeyByLong(mPredicate,
                        (const int64_t *) &startKey->value.asInteger);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }

                ret = gsSetPredicateFinishKeyByLong(mPredicate,
                        (const int64_t *) &finishKey->value.asInteger);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else {
                throw GSException(mPredicate, "not found match type GS_TYPE_LONG");
            }

            if (finishKey->type == GS_TYPE_LONG) {
                ret = gsSetPredicateFinishKeyByLong(mPredicate,
                        (const int64_t *) &finishKey->value.asLong);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else if (finishKey->type == GS_TYPE_INTEGER) {
                ret = gsSetPredicateFinishKeyByLong(mPredicate,
                        (const int64_t *) &finishKey->value.asInteger);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else {
                throw GSException(mPredicate, "not found match type GS_TYPE_LONG");
            }
            break;
        case GS_TYPE_INTEGER:
            if (startKey->type == GS_TYPE_LONG) {
                ret = gsSetPredicateStartKeyByInteger(mPredicate,
                        (const int32_t *) &startKey->value.asLong);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else if (startKey->type == GS_TYPE_INTEGER) {
                ret = gsSetPredicateStartKeyByInteger(mPredicate,
                        (const int32_t *) &startKey->value.asInteger);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else {
                throw GSException(mPredicate, "not found match type GS_TYPE_LONG");
            }

            if (finishKey->type == GS_TYPE_LONG) {
                ret = gsSetPredicateFinishKeyByInteger(mPredicate,
                        (const int32_t *) &finishKey->value.asLong);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else if (finishKey->type == GS_TYPE_INTEGER) {
                ret = gsSetPredicateFinishKeyByInteger(mPredicate,
                        (const int32_t *)&finishKey->value.asInteger);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }
            } else {
                throw GSException(mPredicate, "not found match type GS_TYPE_LONG");
            }
            break;

        case GS_TYPE_STRING:
            ret = gsSetPredicateStartKeyByString(mPredicate,
                    startKey->value.asString);
            if (ret != GS_RESULT_OK) {
                throw GSException(mPredicate, ret);
            }

            ret = gsSetPredicateFinishKeyByString(mPredicate,
                    finishKey->value.asString);
            if (ret != GS_RESULT_OK) {
                throw GSException(mPredicate, ret);
            }
            break;
        case GS_TYPE_TIMESTAMP:
            ret = gsSetPredicateStartKeyByTimestamp(mPredicate,
                    (const GSTimestamp *) &(startKey->value.asTimestamp));
            if (ret != GS_RESULT_OK) {
                throw GSException(mPredicate, ret);
            }
            ret = gsSetPredicateFinishKeyByTimestamp(mPredicate,
                    (const GSTimestamp *) &(startKey->value.asTimestamp));
            if (ret != GS_RESULT_OK) {
                throw GSException(mPredicate, ret);
            }
            break;
        default:
            throw GSException(mPredicate, "Not support type");
            break;
        }
    }
    /*
     * Adds the value of Row key as one of the elements in the individual condition
     */
    void RowKeyPredicate::set_distinct_keys(const Field *keys, size_t keyCount) {
        GSType key_type = get_key_type();
        GSResult ret;
        for (size_t i = 0; i < keyCount; i++) {
            const Field* key = keys + i;
            switch (key_type) {
            case GS_TYPE_LONG:
                if (key->type == GS_TYPE_LONG) {
                    ret = gsAddPredicateKeyByLong(mPredicate, key->value.asLong);
                    if (ret != GS_RESULT_OK) {
                        throw GSException(mPredicate, ret);
                    }

                } else if (key->type == GS_TYPE_INTEGER) {
                    ret = gsAddPredicateKeyByLong(mPredicate, key->value.asInteger);
                    if (ret != GS_RESULT_OK) {
                        throw GSException(mPredicate, ret);
                    }

                } else {
                    throw GSException(mPredicate,
                            "not found match type GS_TYPE_LONG");
                }

                break;
            case GS_TYPE_INTEGER:
                if (key->type == GS_TYPE_LONG) {
                    ret = gsAddPredicateKeyByInteger(mPredicate, key->value.asLong);
                    if (ret != GS_RESULT_OK) {
                        throw GSException(mPredicate, ret);
                    }
                } else if (key->type == GS_TYPE_INTEGER) {
                    ret = gsAddPredicateKeyByInteger(mPredicate,
                            key->value.asInteger);
                    if (ret != GS_RESULT_OK) {
                        throw GSException(mPredicate, ret);
                    }
                } else {
                    throw GSException(mPredicate,
                            "not found match type GS_TYPE_LONG");
                }

                break;
            case GS_TYPE_STRING:
                ret = gsAddPredicateKeyByString(mPredicate, key->value.asString);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }

                break;
            case GS_TYPE_TIMESTAMP:
                ret = gsAddPredicateKeyByTimestamp(mPredicate,
                        key->value.asTimestamp);
                if (ret != GS_RESULT_OK) {
                    throw GSException(mPredicate, ret);
                }

                break;
            default:
                throw GSException(mPredicate, "Not support type");
                break;
            }
        }
    }
    /*
     * Returns a set of the values of the Row keys that configure the individual condition.
     */
    void RowKeyPredicate::get_distinct_keys(Field **keys, size_t* keyCount) {
        size_t size;
        GSType key_type = get_key_type();
        GSValue * keyList;
        GSResult ret = gsGetPredicateDistinctKeysGeneral(mPredicate, (const GSValue **)&keyList, &size);
        *keyCount = size;

        Field* keyFields = (Field *) malloc(size * sizeof (Field));
        memset(keyFields, 0, size * sizeof (Field));
        for(int i =0;i< size; i++) {
            keyFields[i].type = key_type;
            keyFields[i].value = keyList[i];
        }

        *keys = keyFields;
        if (ret != GS_RESULT_OK) {
            throw GSException(mPredicate, ret);
        }
    }
//    /**
//     * Get start key by string. Convert from C-API: gsSetPredicateStartKeyByString
//     */
//    const GSChar* RowKeyPredicate::get_start_key_as_string() {
//        GSChar *startKey;
//        GSResult ret = gsGetPredicateStartKeyAsString(mPredicate, (const GSChar **) &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//
//        return startKey;
//    }
//    /**
//     * Get start key by int. Convert from C-API: gsGetPredicateStartKeyAsInteger
//     */
//    int32_t RowKeyPredicate::get_start_key_as_integer() {
//        int32_t* startKey;
//        GSResult ret = gsGetPredicateStartKeyAsInteger(mPredicate, (const int32_t **) &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//        return *startKey;
//    }
//    /**
//     * Get start key by long. Convert from C-API: gsGetPredicateStartKeyAsLong
//     */
//    int64_t RowKeyPredicate::get_start_key_as_long() {
//        int64_t* startKey;
//        GSResult ret = gsGetPredicateStartKeyAsLong(mPredicate, (const int64_t **) &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//        return *startKey;
//    }
//    /**
//     * Set start key by timestamp. Convert from C-API: gsSetPredicateStartKeyByTimestamp
//     */
//    GSTimestamp RowKeyPredicate::get_start_key_as_timestamp() {
//        GSTimestamp* startKey;
//        GSResult ret = gsGetPredicateStartKeyAsTimestamp(mPredicate, (const GSTimestamp **) &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//        return *startKey;
//    }
//    /**
//     * Set start key by string. Convert from C-API: gsSetPredicateStartKeyByString
//     */
//    void RowKeyPredicate::set_start_key_by_string(const GSChar* startKey) {
//        GSResult ret = gsSetPredicateStartKeyByString(mPredicate, startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Set start key by integer. Convert from C-API: gsSetPredicateStartKeyByInteger
//     */
//    void RowKeyPredicate::set_start_key_by_integer(const int32_t startKey) {
//        GSResult ret = gsSetPredicateStartKeyByInteger(mPredicate, &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Set start key by long. Convert from C-API: gsSetPredicateStartKeyByLong
//     */
//    void RowKeyPredicate::set_start_key_by_long(const int64_t startKey) {
//        GSResult ret = gsSetPredicateStartKeyByLong(mPredicate, &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Set start key by timestamp. Convert from C-API: gsSetPredicateStartKeyByTimestamp
//     */
//    void RowKeyPredicate::set_start_key_by_timestamp(const GSTimestamp startKey) {
//        GSResult ret = gsSetPredicateStartKeyByTimestamp(mPredicate, &startKey);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Get predicate key as integer. Convert from C-API: gsGetPredicateDistinctKeysAsInteger
//     */
//    void RowKeyPredicate::get_predicate_distinct_keys_as_integer(
//            const int **intList, size_t *size) {
//        GSResult ret = gsGetPredicateDistinctKeysAsInteger(mPredicate, intList, size);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Get predicate key as long. Convert from C-API: gsGetPredicateDistinctKeysAsLong
//     */
//    void RowKeyPredicate::get_predicate_distinct_keys_as_long(const long **longList,
//            size_t *size) {
//        GSResult ret = gsGetPredicateDistinctKeysAsLong(mPredicate, longList, size);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Get predicate key as timestamp. Convert from C-API: gsGetPredicateDistinctKeysAsTimestamp
//     */
//    void RowKeyPredicate::get_predicate_distinct_keys_as_timestamp(
//            const long **longList, size_t *size) {
//        GSResult ret = gsGetPredicateDistinctKeysAsTimestamp(mPredicate, longList, size);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Add key by timestamp. Convert from C-API: gsAddPredicateKeyByTimestamp
//     */
//    void RowKeyPredicate::add_key_by_timestamp(GSTimestamp key) {
//        GSResult ret = gsAddPredicateKeyByTimestamp(mPredicate, key);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
//    /**
//     * Get predicate key as string. Convert from C-API: gsGetPredicateDistinctKeysAsString
//     */
//    void RowKeyPredicate::get_predicate_distinct_keys_as_string(
//            const GSChar * const ** stringList, size_t *size) {
//        GSResult ret = gsGetPredicateDistinctKeysAsString(mPredicate, stringList, size);
//        if (ret != GS_RESULT_OK) {
//            throw GSException(mPredicate, ret);
//        }
//    }
    GSRowKeyPredicate* RowKeyPredicate::gs_ptr() {
        return mPredicate;
    }

} /* namespace griddb */
