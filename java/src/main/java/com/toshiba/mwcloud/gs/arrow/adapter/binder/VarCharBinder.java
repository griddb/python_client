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

import java.nio.charset.StandardCharsets;

import org.apache.arrow.memory.util.ArrowBufPointer;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.VariableWidthVector;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.GSType;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.ColumnInfo;
import com.toshiba.mwcloud.gs.Geometry;

/**
 * A binder for variable-width string types.
 *
 * @param <T> The text vector.
 */
public class VarCharBinder<T extends FieldVector & VariableWidthVector> extends BaseColumnBinder<T> {
  private final ArrowBufPointer element;

  /**
   * Create a binder for the given vector using the given GS type for null values.
   *
   * @param vector The vector to draw values from.
   * @param gsType The GS type code.
   */
  public VarCharBinder(T vector, GSType gsType) {
    super(vector, gsType);
    this.element = new ArrowBufPointer();
    //System.out.println("VarCharBinder");
  }

  @Override
  public void bind(Row row, int columnIndex, int rowIndex)
      throws GSException {
    vector.getDataPointer(rowIndex, element);
    if (element.getBuf() == null) {
      row.setNull(columnIndex);
      return;
    }
    if (element.getLength() > (long) Integer.MAX_VALUE) {
      final String message =
          String.format(
              "Length of value at index %d (%d) exceeds Integer.MAX_VALUE",
              rowIndex, element.getLength());
      throw new RuntimeException(message);
    }
    
    byte[] utf8Bytes = new byte[(int) element.getLength()];
    element.getBuf().getBytes(element.getOffset(), utf8Bytes);

    ContainerInfo conInfo = row.getSchema();
    ColumnInfo colInfo = conInfo.getColumnInfo(columnIndex);
    if (colInfo.getType() == GSType.GEOMETRY) {
      String geometryStr = new String(utf8Bytes, StandardCharsets.UTF_8);
      Geometry geometry_data = Geometry.valueOf(geometryStr);
      row.setGeometry(columnIndex, geometry_data);
    } else {   
      row.setString(columnIndex, new String(utf8Bytes, StandardCharsets.UTF_8));
    }
  }
}
