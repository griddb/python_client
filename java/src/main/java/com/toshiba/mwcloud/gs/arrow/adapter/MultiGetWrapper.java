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

package com.toshiba.mwcloud.gs.arrow.adapter;

import java.util.Map;
import java.util.HashMap;
import java.util.List;

import java.io.IOException;

import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.memory.RootAllocator;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.GridStore;
import com.toshiba.mwcloud.gs.RowKeyPredicate;
import com.toshiba.mwcloud.gs.ContainerInfo;

/**
 * GridStore multiGet wrapper class.
 *
 * @since 0.10.0
 */
public class MultiGetWrapper {

  /*----------------------------------------------------------------*
   |                                                                |
   |          GridDB GridStore multiGet wrapper                     |
   |                                                                |
   *----------------------------------------------------------------*/

  /**
   * Register Map<container name, containerPredicateMap> and notify the data issued by GridStore.multiGet with VectorSchemaRoot.
   *
   * @param GridStore store Specify the GridStore that issues GridStore.multiGet.
   * @param Map<String,? extends RowKeyPredicate<?>> predicateEntry  Specifies the containerPredicateMap to use when issuing a multiGet.
   * @param rootAllocator Memory allocator
   * @return multiGetWrapper Objects {@link ArrowVectorIterator}
   * @throws GSException on error
   */
  private GridStore store;
  private Map<String,? extends RowKeyPredicate<?>> predicateEntry;
  private RootAllocator rootAllocator;
  private Map<String, List<Row>> containerRusultListMap;
 
  /**
   * Construct an instance.
   */
  public MultiGetWrapper (
      GridStore store,
      Map<String,? extends RowKeyPredicate<?>> predicateEntry,
      RootAllocator rootAllocator) {
    this.store = store;
    this.predicateEntry = predicateEntry;
    this.rootAllocator = rootAllocator; 
    this.containerRusultListMap = null;
  }

  /**
   * Execute GridStore.multiGet.
   */
  public void execute() throws GSException, IOException {
    containerRusultListMap = store.multiGet(predicateEntry);
  }

  /**
   * Notifies the number of Map entries notified by GridStore.multiGet.
   */
  public int size() {
    return containerRusultListMap.size();
  }

  /**
   * Converts the List<Row> of the specified containerName to a VectorSchemaRoot and notifies it.
   */
  public VectorSchemaRoot get(String containerName) throws GSException, IOException {
    
    if (!containerRusultListMap.containsKey(containerName)) {
      return null;
    }

    List<Row> rowList = containerRusultListMap.get(containerName);
    if (rowList.size() == 0) {
      return null;
    }

    ContainerInfo containerInfo = rowList.get(0).getSchema();

    if (containerInfo == null) {
      return null;
    }

    ArrowVectorIterator it = JavaAPIToArrow.javaAPIToArrowVectorIterator(containerInfo, rootAllocator);
    VectorSchemaRoot root = it.getRootRow(rowList);

    return root;
  }
}
