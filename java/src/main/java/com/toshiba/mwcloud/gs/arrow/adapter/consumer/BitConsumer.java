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

import org.apache.arrow.vector.BitVector;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;
import com.toshiba.mwcloud.gs.GSException;

/**
 * Consumer which consume bit type values from {@link RowSet}. Write the data to {@link
 * BitVector}.
 */
public class BitConsumer {

  /** Creates a consumer for {@link BitVector}. */
  public static JavaAPIConsumer<BitVector> createConsumer(
      BitVector vector, int index, boolean nullable) {
    if (nullable) {
      return new NullableBitConsumer(vector, index);
    } else {
      return new NonNullableBitConsumer(vector, index);
    }
  }

  /** Nullable consumer for {@link BitVector}. */
  static class NullableBitConsumer extends BaseConsumer<BitVector> {

    /** Instantiate a BitConsumer. */
    public NullableBitConsumer(BitVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      boolean value = row.getBool(columnIndexInRowSet);
      if (!row.isNull(columnIndexInRowSet)) {
        // for fixed width vectors, we have allocated enough memory proactively,
        // so there is no need to call the setSafe method here.
        vector.set(currentIndex, value ? 1 : 0);
      }
      currentIndex++;
    }
  }

  /** Non-nullable consumer for {@link BitVector}. */
  static class NonNullableBitConsumer extends BaseConsumer<BitVector> {

    /** Instantiate a BitConsumer. */
    public NonNullableBitConsumer(BitVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      boolean value = row.getBool(columnIndexInRowSet);
      // for fixed width vectors, we have allocated enough memory proactively,
      // so there is no need to call the setSafe method here.
      vector.set(currentIndex, value ? 1 : 0);
      currentIndex++;
    }
  }
}
