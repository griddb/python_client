/* * Licensed to the Apache Software Foundation (ASF) under one or more
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

//import javax.sql.RowSet;

import org.apache.arrow.vector.Float8Vector;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;

/**
 * Consumer which consume double type values from {@link RowSet}. Write the data to {@link
 * org.apache.arrow.vector.Float8Vector}.
 */
public class DoubleConsumer {

  /** Creates a consumer for {@link Float8Vector}. */
  public static JavaAPIConsumer<Float8Vector> createConsumer(
      Float8Vector vector, int index, boolean nullable) {
    if (nullable) {
      return new NullableDoubleConsumer(vector, index);
    } else {
      return new NonNullableDoubleConsumer(vector, index);
    }
  }

  /** Nullable double consumer. */
  static class NullableDoubleConsumer extends BaseConsumer<Float8Vector> {

    /** Instantiate a DoubleConsumer. */
    public NullableDoubleConsumer(Float8Vector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException{
      double value = row.getDouble(columnIndexInRowSet);
      if (!row.isNull(columnIndexInRowSet)) {
        // for fixed width vectors, we have allocated enough memory proactively,
        // so there is no need to call the setSafe method here.
        vector.set(currentIndex, value);
      }
      currentIndex++;
    }
  }

  /** Non-nullable double consumer. */
  static class NonNullableDoubleConsumer extends BaseConsumer<Float8Vector> {

    /** Instantiate a DoubleConsumer. */
    public NonNullableDoubleConsumer(Float8Vector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      double value = row.getDouble(columnIndexInRowSet);
      // for fixed width vectors, we have allocated enough memory proactively,
      // so there is no need to call the setSafe method here.
      vector.set(currentIndex, value);
      currentIndex++;
    }
  }
}
