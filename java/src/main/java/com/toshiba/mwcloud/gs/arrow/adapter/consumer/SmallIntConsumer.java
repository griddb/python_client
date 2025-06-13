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

import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.GSException;
import org.apache.arrow.vector.SmallIntVector;

/**
 * Consumer which consume smallInt type values from {@link Row}. Write the data to {@link
 * org.apache.arrow.vector.SmallIntVector}.
 */
public class SmallIntConsumer {

  /** Creates a consumer for {@link SmallIntVector}. */
  public static BaseConsumer<SmallIntVector> createConsumer(
      SmallIntVector vector, int index, boolean nullable) {
    if (nullable) {
      return new NullableSmallIntConsumer(vector, index);
    } else {
      return new NonNullableSmallIntConsumer(vector, index);
    }
  }

  /** Nullable consumer for small int. */
  static class NullableSmallIntConsumer extends BaseConsumer<SmallIntVector> {

    /** Instantiate a SmallIntConsumer. */
    public NullableSmallIntConsumer(SmallIntVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      short value = row.getShort(columnIndexInRowSet);
      if (!row.isNull(columnIndexInRowSet)) {
        // for fixed width vectors, we have allocated enough memory proactively,
        // so there is no need to call the setSafe method here.
        vector.set(currentIndex, value);
      }
      currentIndex++;
    }
  }

  /** Non-nullable consumer for small int. */
  static class NonNullableSmallIntConsumer extends BaseConsumer<SmallIntVector> {

    /** Instantiate a SmallIntConsumer. */
    public NonNullableSmallIntConsumer(SmallIntVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      short value = row.getShort(columnIndexInRowSet);
      // for fixed width vectors, we have allocated enough memory proactively,
      // so there is no need to call the setSafe method here.
      vector.set(currentIndex, value);
      currentIndex++;
    }
  }
}
