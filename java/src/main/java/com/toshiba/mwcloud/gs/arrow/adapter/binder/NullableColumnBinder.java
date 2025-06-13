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
import org.apache.arrow.vector.FieldVector;

/** A ColumnBinder that checks for nullability before deferring to a type-specific binder. */
public class NullableColumnBinder implements ColumnBinder {
  private final ColumnBinder wrapped;

  public NullableColumnBinder(ColumnBinder wrapped) {
    this.wrapped = wrapped;
  }

  @Override
  public void bind(Row row, int columnIndex, int rowIndex)
      throws GSException {
    if (wrapped.getVector().isNull(rowIndex)) {
      row.setNull(columnIndex);//
    } else {
      wrapped.bind(row, columnIndex, rowIndex);
    }
  }

  @Override
  public GSType getGSType() {
    return wrapped.getGSType();
  }

  @Override
  public FieldVector getVector() {
    return wrapped.getVector();
  }
}
