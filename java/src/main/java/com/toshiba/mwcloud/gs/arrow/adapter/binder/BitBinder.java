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
package com.toshiba.mwcloud.gs.arrow.adapter.binder;

import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.GSType;
import com.toshiba.mwcloud.gs.GSException;
import java.sql.Types;
import org.apache.arrow.vector.BitVector;

/** A column binder for booleans. */
public class BitBinder extends BaseColumnBinder<BitVector> {
  public BitBinder(BitVector vector) {
    this(vector, GSType.BOOL);
  }

  public BitBinder(BitVector vector, GSType gsType) {
    super(vector, gsType);
  }

  @Override
  public void bind(Row row, int columnIndex, int rowIndex)
      throws GSException {
    // See BitVector#getBit
    final int byteIndex = rowIndex >> 3;
    final byte b = vector.getDataBuffer().getByte(byteIndex);
    final int bitIndex = rowIndex & 7;
    final int value = (b >> bitIndex) & 0x01;
    row.setBool(columnIndex, value != 0);
  }
}
