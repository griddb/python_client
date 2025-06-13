/*
    Copyright (c) 2024 TOSHIBA Digital Solutions Corporation

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

package com.toshiba.mwcloud.gs.arrow.adapter; //
import java.util.Map;
import java.util.HashMap;
import java.util.List;

import java.io.IOException;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.memory.RootAllocator;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.GridStore;
import com.toshiba.mwcloud.gs.Container;
import com.toshiba.mwcloud.gs.arrow.adapter.JavaAPIParameterBinder;

/**
 * GridStore multiPut wrapper class.
 *
 * @since 0.10.0
 */
public class MultiPutWrapper {

  /*----------------------------------------------------------------*
   |                                                                |
   |          GridDB GridStore multiPut wrapper                     |
   |                                                                |
   *----------------------------------------------------------------*/

  /**
   * A wapper that registers the data specified in Map<container name, RecordBatch> to GridDB using multiPut.
   *
   * @param GridStore store Specify the GridStore that issues multiGet.
   * @return multiPutWrapper Objects {@link multiPutWrapper}
   * @throws GSException on error
   */
  private GridStore store;
  private Map<String, List<Row>> containerEntryMap;
  
  /**
   * Construct an instance.
   */
  public MultiPutWrapper(GridStore store) {
    this.store = store;
    this.containerEntryMap = new HashMap<>();
  }

  /**
   * Execute multiPut.
   */
  public void execute() throws GSException, IOException {
    store.multiPut(containerEntryMap);
  }

  /**
   * Set containerRowsMap for Gridstore.multiPut with the specified container name and RecordBatch.
   */
  public Boolean setRoot(String containerName, VectorSchemaRoot root) throws GSException, IOException {
    Container<?, Row> container = store.getContainer(containerName);
    if (container == null) {
      return false;
    }

    JavaAPIParameterBinder binder = JavaAPIParameterBinder.builder(container, root).bindAll().build();
    List<Row> rowList = binder.getList();
    containerEntryMap.put(containerName, rowList);
    return true;
  }
}
