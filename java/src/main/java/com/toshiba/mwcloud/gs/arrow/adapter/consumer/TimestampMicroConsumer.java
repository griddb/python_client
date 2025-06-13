/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.toshiba.mwcloud.gs.arrow.adapter.consumer;

import java.sql.Timestamp;
import java.util.Date;

import org.apache.arrow.vector.TimeStampMicroVector;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;
import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.ColumnInfo;
import com.toshiba.mwcloud.gs.TimeUnit;

/**
 * Consumer which consume timestamp type values from {@link RowSet}. Write the data to {@link
 * TimeStampMicroVector}.
 */
public abstract class TimestampMicroConsumer {

  /** Creates a consumer for {@link TimeStampMicroVector}. */
  public static JavaAPIConsumer<TimeStampMicroVector> createConsumer(
      TimeStampMicroVector vector, int index, boolean nullable) {
    if (nullable) {
      return new NullableTimestampConsumer(vector, index);
    } else {
      return new NonNullableTimestampConsumer(vector, index);
    }
  }

  /** Nullable consumer for timestamp. */
  static class NullableTimestampConsumer extends BaseConsumer<TimeStampMicroVector> {


    /** Instantiate a TimestampConsumer. */
    public NullableTimestampConsumer(TimeStampMicroVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      ContainerInfo conInfo = row.getSchema();
      ColumnInfo colInfo = conInfo.getColumnInfo(columnIndexInRowSet);
      if (colInfo.getTimePrecision() == TimeUnit.MICROSECOND || colInfo.getTimePrecision() == TimeUnit.NANOSECOND) {
        Timestamp timestamp = row.getPreciseTimestamp(columnIndexInRowSet);
        if (!row.isNull(columnIndexInRowSet)) {
          // for fixed width vectors, we have allocated enough memory proactively,
          // so there is no need to call the setSafe method here.
          vector.set(currentIndex, timestamp.getTime());
        }
      } else {
        Date timestamp = row.getTimestamp(columnIndexInRowSet);
        if (!row.isNull(columnIndexInRowSet)) {
          // for fixed width vectors, we have allocated enough memory proactively,
          // so there is no need to call the setSafe method here.
          vector.set(currentIndex, timestamp.getTime());
        }
      }
      currentIndex++;
    }
  }

  /** Non-nullable consumer for timestamp. */
  static class NonNullableTimestampConsumer extends BaseConsumer<TimeStampMicroVector> {

    public NonNullableTimestampConsumer(TimeStampMicroVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
    /** Instantiate a TimestampConsumer. */
      ContainerInfo conInfo = row.getSchema();
      ColumnInfo colInfo = conInfo.getColumnInfo(columnIndexInRowSet);
      if (colInfo.getTimePrecision() == TimeUnit.MICROSECOND || colInfo.getTimePrecision() == TimeUnit.NANOSECOND) {
        Timestamp timestamp = row.getPreciseTimestamp(columnIndexInRowSet);
        // for fixed width vectors, we have allocated enough memory proactively,
        // so there is no need to call the setSafe method here.
        vector.set(currentIndex, timestamp.getTime());
      } else {
        Date timestamp = row.getTimestamp(columnIndexInRowSet);
        // for fixed width vectors, we have allocated enough memory proactively,
        // so there is no need to call the setSafe method here.
        vector.set(currentIndex, timestamp.getTime());
      }
      currentIndex++;
    }
  }
}
