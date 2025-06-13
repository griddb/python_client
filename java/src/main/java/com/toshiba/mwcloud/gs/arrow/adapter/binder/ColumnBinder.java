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

/** A helper to bind values from a wrapped Arrow vector to a JavaAPI Row */
public interface ColumnBinder {
  /**
   * Bind the given row to the given parameter.
   *
   * @param row The row to bind to.
   * @param columnIndex The parameter to bind to (1-indexed)
   * @param rowIndex The row to bind values from (0-indexed)
   * @throws GSException if an error occurs
   */
  void bind(Row row, int columnIndex, int rowIndex) throws GSException;

  /**
   * Get the GS type code used by this binder.
   *
   * @return A type code from {@link com.toshiba.mwcloud.gs.GSType}.
   */
  GSType getGSType();

  /** Get the vector used by this binder. */
  FieldVector getVector();

  /** Create a column binder for a vector, using the default GS type code for null values. */
  static ColumnBinder forVector(FieldVector vector) {
    return forVector(vector, /*gsType*/ null);
  }

  /**
   * Create a column binder for a vector, overriding the GS type code used for null values.
   *
   * @param vector The vector that the column binder will wrap.
   * @param gsType The GS type code to use (or null to use the default).
   */
  static ColumnBinder forVector(FieldVector vector, Integer gsType) {
    final ColumnBinder binder =
        vector.getField().getType().accept(new ColumnBinderArrowTypeVisitor(vector, /*gsType*/ null));
    if (vector.getField().isNullable()) {
      return new NullableColumnBinder(binder);
    }
    return binder;
  }
}
