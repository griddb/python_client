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
import org.apache.arrow.vector.BigIntVector;

/** A column binder for 8-bit integers. */
public class BigIntBinder extends BaseColumnBinder<BigIntVector> {
  public BigIntBinder(BigIntVector vector) {
    this(vector, GSType.LONG);
  }

  public BigIntBinder(BigIntVector vector, GSType gsType) {
    super(vector, gsType);
  }

  @Override
  public void bind(Row row, int columnIndex, int rowIndex) throws GSException {
    final long value = vector.getDataBuffer().getLong((long) rowIndex * BigIntVector.TYPE_WIDTH);
    row.setLong(columnIndex, (long)value);
  }
}
