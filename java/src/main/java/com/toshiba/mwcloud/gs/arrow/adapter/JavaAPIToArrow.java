/*
    Copyright (c) 2024 TOSHIBA Digital Solutions Corporation
    Copyright (c) The Apache Software Foundation (ASF)

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

import java.io.IOException;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.util.Preconditions;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;
import com.toshiba.mwcloud.gs.ContainerInfo;

/**
 * Utility class to convert GridDB JavaAPI objects to columnar Arrow format objects.
 *
 * <p>This utility uses following data mapping to map GSType datatype to Arrow data types.
 *
 * <p>STRING --> ArrowType.Utf8
 * BIT --> ArrowType.Bool
 * BYTE --> ArrowType.Int(8, signed)
 * SMALLINT --> ArrowType.Int(16, signed)
 * INTEGER --> ArrowType.Int(32, signed)
 * LONG --> ArrowType.Int(64, signed)
 * FLOAT --> ArrowType.FloatingPoint(FloatingPointPrecision.SINGLE)
 * DOUBLE --> ArrowType.FloatingPoint(FloatingPointPrecision.DOUBLE)
 * TIMESTAMP --> ArrowType.Timestamp(TimeUnit.MILLISECOND, timezone=null)
 * BLOB --> ArrowType.Binary
 *
 * @since 0.10.0
 */
public class JavaAPIToArrow {

  /*----------------------------------------------------------------*
   |                                                                |
   |          Partial Convert API                        |
   |                                                                |
   *----------------------------------------------------------------*/

  /**
   * For the given JavaAPI {@link RowSet}, fetch the data from Relational DB and convert it to Arrow objects.
   * Note here uses the default targetBatchSize = 1024.
   *
   * @param rowSet RowSet to use to fetch the data from underlying database
   * @param allocator Memory allocator
   * @return Arrow Data Objects {@link ArrowVectorIterator}
   * @throws GSException on error
   */
  public static ArrowVectorIterator javaAPIToArrowVectorIterator(
      RowSet<Row> rowSet,
      BufferAllocator allocator)
      throws GSException, IOException {
    Preconditions.checkNotNull(allocator, "Memory Allocator object cannot be null");

    JavaAPIToArrowConfig config =
        new JavaAPIToArrowConfig(allocator, JavaAPIToArrowUtils.getUtcCalendar());
    return javaAPIToArrowVectorIterator(rowSet, config);
  }

  /**
   * For the given JavaAPI {@link ContainerInfo}, fetch the data from Relational DB and convert it to Arrow objects.
   * Note here uses the default targetBatchSize = 1024.
   *
   * @param containerInfo Containerinfo to use to fetch the data from underlying database
   * @param allocator Memory allocator
   * @return Arrow Data Objects {@link ArrowVectorIterator}
   * @throws GSException on error
   */
  public static ArrowVectorIterator javaAPIToArrowVectorIterator(
      ContainerInfo containerInfo,
      BufferAllocator allocator)
      throws GSException, IOException {
    Preconditions.checkNotNull(allocator, "Memory Allocator object cannot be null");

    JavaAPIToArrowConfig config =
        new JavaAPIToArrowConfig(allocator, JavaAPIToArrowUtils.getUtcCalendar());
    return javaAPIToArrowVectorIterator(containerInfo, config);
  }

  /**
   * For the given JavaAPI {@link RowSet}, fetch the data from Relational DB and convert it to Arrow objects.
   * Note if not specify {@link JavaAPIToArrowConfig#targetBatchSize}, will use default value 1024.
   * @param rowSet RowSet to use to fetch the data from underlying database
   * @param config    Configuration of the conversion from GridDB JavaAPI to Arrow.
   * @return Arrow Data Objects {@link ArrowVectorIterator}
   * @throws GSException on error
   */
  public static ArrowVectorIterator javaAPIToArrowVectorIterator(
      RowSet<Row> rowSet,
      JavaAPIToArrowConfig config)
      throws GSException, IOException {
    Preconditions.checkNotNull(rowSet, "JavaAPI RowSet object cannot be null");
    Preconditions.checkNotNull(config, "The configuration cannot be null");
    return ArrowVectorIterator.create(rowSet, config);
  }

  /**
   * For the given JavaAPI {@link ContainerInfo}, fetch the data from Relational DB and convert it to Arrow objects.
   * Note if not specify {@link JavaAPIToArrowConfig#targetBatchSize}, will use default value 1024.
   * @param containerInfo ContainerInfo to use to fetch the data from underlying database
   * @param config    Configuration of the conversion from GridDB JavaAPI to Arrow.
   * @return Arrow Data Objects {@link ArrowVectorIterator}
   * @throws GSException on error
   */
  public static ArrowVectorIterator javaAPIToArrowVectorIterator(
      ContainerInfo containerInfo,
      JavaAPIToArrowConfig config)
      throws GSException, IOException {
    Preconditions.checkNotNull(containerInfo, "JavaAPI ContainerInfo object cannot be null");
    Preconditions.checkNotNull(config, "The configuration cannot be null");
    return ArrowVectorIterator.create(containerInfo, config);
  }
}
