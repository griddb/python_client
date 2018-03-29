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

#include "PartitionController.h"

namespace griddb {

    PartitionController::PartitionController(GSPartitionController *controller) :
        mController(controller) {
    }
    /**
     * Destructor. Convert from C-API:gsClosePartitionController
     */
    PartitionController::~PartitionController() {
        close();
    }
    void PartitionController::close() {
        if (mController != NULL) {
            gsClosePartitionController(&mController);
            mController = NULL;
        }
    }
    /**
     * Get partition count. Convert from C-Api: gsGetPartitionCount
     */
    int32_t PartitionController::get_partition_count() {
        int32_t value;
        GSResult ret = gsGetPartitionCount(mController, &value);

        // Check ret, if error, throw exception
        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
        return value;
    }
    /**
     * Get container partition count. Convert from C-Api: gsGetPartitionContainerCount
     */
    int64_t PartitionController::get_container_count(int32_t partition_index) {
        int64_t value;
        GSResult ret = gsGetPartitionContainerCount(mController, partition_index,&value);

        // Check ret, if error, throw exception
        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
        return value;
    }
    /**
     * Get list partition container names case there is limit. Convert from C-Api: gsGetPartitionContainerNames
     */
    void PartitionController::get_container_names(int32_t partitionIndex, int64_t start,
            const GSChar * const ** stringList, size_t *size, int64_t limit) {
        int64_t* limitPtr;
        if (limit >= 0) {
            limitPtr = &limit;
        } else {
            limitPtr = NULL;
        }
        GSResult ret = gsGetPartitionContainerNames(mController, partitionIndex, start, limitPtr, stringList, size);

        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
    }
    /**
     * Get get_partition hosts. Convert from C-Api: gsGetPartitionHosts
     */
    void PartitionController::get_partition_hosts(int32_t partitionIndex, const GSChar * const **stringList, size_t *size) {
        GSResult ret = gsGetPartitionHosts(mController, partitionIndex, stringList, size);

        // Check ret, if error, throw exception
        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
    }
    /**
     * Get get_partition index of container. Convert from C-Api: gsGetPartitionIndexOfContainer
     */
    int32_t PartitionController::get_partition_index_of_container(const GSChar* container_name) {
        int32_t value;
        GSResult ret = gsGetPartitionIndexOfContainer(mController, container_name, &value);

        // Check ret, if error, throw exception
        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
        return value;
    }
    /**
     * Get get_partition owner host. Convert from C-Api: gsGetPartitionOwnerHost
     */
    string PartitionController::get_partition_owner_host(int32_t partitionIndex) {
        const GSChar *address;
        GSResult ret = gsGetPartitionOwnerHost(mController, partitionIndex, &address);

        // Check ret, if error, throw exception
        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
        return address;
    }

    /**
     * Get get_partition backup hosts. Convert from C-Api: gsGetPartitionBackupHosts
     */
    void PartitionController::get_partition_backup_hosts(int32_t partitionIndex, const GSChar *const **stringList, size_t *size) {
        GSResult ret = gsGetPartitionBackupHosts(mController, partitionIndex, stringList, size);

        // Check ret, if error, throw exception
        if (ret != GS_RESULT_OK) {
            throw GSException(mController, ret);
        }
    }

    /**
     * Assign host. Convert from C-Api: gsAssignPartitionPreferableHost
     */
    void PartitionController::assign_partition_preferable_host(int32_t partitionIndex, const GSChar* host) {
        GSResult ret = gsAssignPartitionPreferableHost(mController, partitionIndex, host);
        if (ret != GS_RESULT_OK) {
            throw new GSException(ret);
        }
    }

} /* namespace griddb */
