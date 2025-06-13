/*
 * Copyright (c) 2024 TOSHIBA Digital Solutions Corporation
 * Copyright (c) The Apache Software Foundation (ASF)

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 *    http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.toshiba.mwcloud.gs.arrow.adapter;

import static com.toshiba.mwcloud.gs.arrow.adapter.JavaAPIToArrowUtils.isColumnNullable;

import java.util.Iterator;
import java.util.List;

import org.apache.arrow.util.AutoCloseables;
import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.types.pojo.ArrowType;
import org.apache.arrow.vector.types.pojo.Schema;
import org.apache.arrow.vector.util.ValueVectorUtility;

import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;
import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.QueryAnalysisEntry;
import com.toshiba.mwcloud.gs.AggregationResult;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.CompositeJavaAPIConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.JavaAPIConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.exceptions.JavaAPIConsumerException;

/**
 * VectorSchemaRoot iterator for partially converting GridDB JavaAPI data.
 */
public class ArrowVectorIterator implements Iterator<VectorSchemaRoot>, AutoCloseable {

  private final RowSet<Row> rowSet;
  private final JavaAPIToArrowConfig config;

  private final Schema schema;
  private final ContainerInfo conInfo;

  private final JavaAPIConsumer[] consumers;
  final CompositeJavaAPIConsumer compositeConsumer;

  // this is used only if resuing vector schema root is enabled.
  private VectorSchemaRoot nextBatch;

  private final int targetBatchSize;

  // This is used to track whether the ResultSet has been fully read, and is needed specifically for cases where there
  // is a ResultSet having zero rows (empty):
  private boolean readComplete = false;
  private int remainCount = 0;

  /**
   * Construct an instance.
   */
  private ArrowVectorIterator(RowSet<Row> rowSet, JavaAPIToArrowConfig config) throws GSException {
    this.rowSet = rowSet;
    this.conInfo = rowSet.getSchema();
    this.config = config;
    this.schema = JavaAPIToArrowUtils.javaAPIToArrowSchema(conInfo, config);
    this.targetBatchSize = config.getTargetBatchSize();

    consumers = new JavaAPIConsumer[conInfo.getColumnCount()];
    this.compositeConsumer = new CompositeJavaAPIConsumer(consumers);
    this.nextBatch = config.isReuseVectorSchemaRoot() ? createVectorSchemaRoot() : null;
  }

  private ArrowVectorIterator(ContainerInfo containerInfo, JavaAPIToArrowConfig config) throws GSException {
    this.rowSet = null;
    this.conInfo = containerInfo;
    this.config = config;
    this.schema = JavaAPIToArrowUtils.javaAPIToArrowSchema(conInfo, config);
    this.targetBatchSize = config.getTargetBatchSize();

    consumers = new JavaAPIConsumer[conInfo.getColumnCount()];
    this.compositeConsumer = new CompositeJavaAPIConsumer(consumers);
    this.nextBatch = config.isReuseVectorSchemaRoot() ? createVectorSchemaRoot() : null;
  }

  /**
   * Create a ArrowVectorIterator to partially convert data.
   */
  public static ArrowVectorIterator create(
      RowSet<Row> rowSet,
      JavaAPIToArrowConfig config)
      throws GSException {
    ArrowVectorIterator iterator = null;
    try {
      iterator = new ArrowVectorIterator(rowSet, config);
    } catch (Throwable e) {
      AutoCloseables.close(e, iterator);
      throw new RuntimeException("Error occurred while creating iterator.", e);
    }
    return iterator;
  }

  /**
   * Create a ArrowVectorIterator to partially convert data.
   */
  public static ArrowVectorIterator create(
      ContainerInfo containerInfo,
      JavaAPIToArrowConfig config)
      throws GSException {
    ArrowVectorIterator iterator = null;
    try {
      iterator = new ArrowVectorIterator(containerInfo, config);
    } catch (Throwable e) {
      AutoCloseables.close(e, iterator);
      throw new RuntimeException("Error occurred while creating iterator.", e);
    }
    return iterator;
  }

  private void consumeData(VectorSchemaRoot root) {
    // consume data
    try {
      int readRowCount = 0;
      if (targetBatchSize == JavaAPIToArrowConfig.NO_LIMIT_BATCH_SIZE) {
        while (rowSet.hasNext()) {
          Object row_check = rowSet.next();
          if (row_check instanceof QueryAnalysisEntry) {
              throw new Exception("QueryAnalysisEntry is not supported.");
          } else {
              if (row_check instanceof AggregationResult) {
                  throw new Exception("AggregationResult is not supported.");
              }
          }
          Row row = (Row) row_check;
          
          ValueVectorUtility.ensureCapacity(root, readRowCount + 1);
          compositeConsumer.consume(row);
          readRowCount++;
        }
        readComplete = true;
      } else {
        while ((readRowCount < targetBatchSize) && !readComplete) {
          if (rowSet.hasNext()) {
            Row row = rowSet.next();
            compositeConsumer.consume(row);
            readRowCount++;
          } else {
            readComplete = true;
          }
        }
      }

      root.setRowCount(readRowCount);
    } catch (Throwable e) {
      compositeConsumer.close();
      if (e instanceof JavaAPIConsumerException) {
        throw (JavaAPIConsumerException) e;
      } else {
        if (e.getMessage()=="AggregationResult is not supported." ||
          e.getMessage()=="QueryAnalysisEntry is not supported.")  {
          throw new RuntimeException(e.getMessage(), e);
        } else {
          throw new RuntimeException("Error occurred while consuming data.", e);
        }
      }
    }
  }

  private void consumeDataRow(VectorSchemaRoot root, List<Row> rowList) {
    // consume data
    try {
      int readRowCount = 0;
      if (targetBatchSize == JavaAPIToArrowConfig.NO_LIMIT_BATCH_SIZE) {
        for (int i=remainCount; i<rowList.size();i++) {
          Object row_check = rowList.get(i);
          if (row_check instanceof QueryAnalysisEntry) {
              throw new Exception("QueryAnalysisEntry is not supported.");
          } else {
              if (row_check instanceof QueryAnalysisEntry) {
                  throw new Exception("QueryAnalysisEntry is not supported.");
              }
          }
          Row row = (Row) row_check;
          remainCount++;

          ValueVectorUtility.ensureCapacity(root, readRowCount + 1);
          compositeConsumer.consume(row);
          readRowCount++;
        }
        readComplete = true;
        remainCount = 0;
      } else {
        while ((readRowCount < targetBatchSize) && !readComplete) {
          if (remainCount < rowList.size()) { 
            Row row = rowList.get(remainCount);
            remainCount++;
            compositeConsumer.consume(row);
            readRowCount++;
          } else {
            readComplete = true;
            remainCount = 0;
          }
        }
      }

      root.setRowCount(readRowCount);
    } catch (Throwable e) {
      compositeConsumer.close();
      if (e instanceof JavaAPIConsumerException) {
        throw (JavaAPIConsumerException) e;
      } else {
        if (e.getMessage()=="AggregationResult is not supported." ||
          e.getMessage()=="QueryAnalysisEntry is not supported.")  {
          throw new RuntimeException(e.getMessage(), e);
        } else {
          throw new RuntimeException("Error occurred while consuming data.", e);
        }
      }
    }
  }

  private VectorSchemaRoot createVectorSchemaRoot() throws GSException {
    VectorSchemaRoot root = null;
    try {
      root = VectorSchemaRoot.create(schema, config.getAllocator());
      if (config.getTargetBatchSize() != JavaAPIToArrowConfig.NO_LIMIT_BATCH_SIZE) {
        ValueVectorUtility.preAllocate(root, config.getTargetBatchSize());
      }
    } catch (Throwable e) {
      if (root != null) {
        root.close();
      }
      throw new RuntimeException("Error occurred while creating schema root.", e);
    }
    initialize(root);
    return root;
  }

  private void initialize(VectorSchemaRoot root) throws GSException {
    for (int i = 0; i < consumers.length; i++) {
      final JavaAPIFieldInfo columnFieldInfo = JavaAPIToArrowUtils.getJavaAPIFieldInfoForColumn(conInfo, i, config);
      ArrowType arrowType = config.getJavaAPIToArrowTypeConverter().apply(columnFieldInfo);
      consumers[i] = config.getJavaAPIConsumerGetter().apply(
          arrowType, i, isColumnNullable(conInfo, i, columnFieldInfo), root.getVector(i), config);
    }
  }

  // Loads the next schema root or null if no more rows are available.
  private void load(VectorSchemaRoot root) {
    for (int i = 0; i < consumers.length; i++) {
      FieldVector vec = root.getVector(i);
      if (config.isReuseVectorSchemaRoot()) {
        // if we are reusing the vector schema root,
        // we must reset the vector before populating it with data.
        vec.reset();
      }
      consumers[i].resetValueVector(vec);
    }

    consumeData(root);
  }

  // Loads the next schema root or null if no more rows are available.
  private void loadRow(VectorSchemaRoot root, List<Row> rowList) {
    for (int i = 0; i < consumers.length; i++) {
      FieldVector vec = root.getVector(i);
      if (config.isReuseVectorSchemaRoot()) {
        // if we are reusing the vector schema root,
        // we must reset the vector before populating it with data.
        vec.reset();
      }
      consumers[i].resetValueVector(vec);
    }

    consumeDataRow(root, rowList);
  }

  @Override
  public boolean hasNext() {
    return !readComplete;
  }

  @Override
  public VectorSchemaRoot next() {
    Preconditions.checkArgument(hasNext());
    try {
      VectorSchemaRoot ret = config.isReuseVectorSchemaRoot() ? nextBatch : createVectorSchemaRoot();
      load(ret);
      return ret;
    } catch (Exception e) {
      close();
      if (e instanceof JavaAPIConsumerException) {
        throw (JavaAPIConsumerException) e;
      } else {
        if (e.getMessage()=="AggregationResult is not supported." || 
          e.getMessage()=="QueryAnalysisEntry is not supported.")  {
          throw new RuntimeException(e.getMessage(), e);
        } else {
          throw new RuntimeException("Error occurred while getting next schema root.", e);
        }
      }
    }
  }

  public VectorSchemaRoot getRootRow(List<Row> rowList) {
    try {
      VectorSchemaRoot ret = createVectorSchemaRoot();
      loadRow(ret, rowList);
      return ret;
    } catch (Exception e) {
      close();
      if (e instanceof JavaAPIConsumerException) {
        throw (JavaAPIConsumerException) e;
      } else {
        System.out.println(e.getMessage());
        if (e.getMessage()=="AggregationResult is not supported." ||
          e.getMessage()=="QueryAnalysisEntry is not supported.")  {
          throw new RuntimeException(e.getMessage(), e);
        } else {
          throw new RuntimeException("Error occurred while getting next schema root.", e);
        }
      }
    }
  }

  /**
   * Clean up resources ONLY WHEN THE {@link VectorSchemaRoot} HOLDING EACH BATCH IS REUSED. If a new VectorSchemaRoot
   * is created for each batch, each root must be closed manually by the client code.
   */
  @Override
  public void close() {
    if (config.isReuseVectorSchemaRoot()) {
      nextBatch.close();
      compositeConsumer.close();
    }
  }
}
