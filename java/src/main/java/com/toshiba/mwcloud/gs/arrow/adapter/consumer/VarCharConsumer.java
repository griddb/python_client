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
package com.toshiba.mwcloud.gs.arrow.adapter.consumer;

import java.nio.charset.StandardCharsets;

import org.apache.arrow.vector.VarCharVector;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;
import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.ColumnInfo;
import com.toshiba.mwcloud.gs.GSType;
import com.toshiba.mwcloud.gs.Geometry;

/**
 * Consumer which consume varchar type values from {@link RowSet}. Write the data to {@link
 * org.apache.arrow.vector.VarCharVector}.
 */
public abstract class VarCharConsumer {

  /** Creates a consumer for {@link VarCharVector}. */
  public static JavaAPIConsumer<VarCharVector> createConsumer(
  	  VarCharVector vector, int index, boolean nullable) {
    if (nullable) {
      return new NullableVarCharConsumer(vector, index);
    } else {
      return new NonNullableVarCharConsumer(vector, index);
    }
  }

  /** Nullable consumer for var char. */
  static class NullableVarCharConsumer extends BaseConsumer<VarCharVector> {

    /** Instantiate a VarCharConsumer. */
    public NullableVarCharConsumer(VarCharVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      ContainerInfo conInfo = row.getSchema();
      ColumnInfo colInfo = conInfo.getColumnInfo(columnIndexInRowSet);
      String value = null;
      if (colInfo.getType() == GSType.GEOMETRY) {
        Geometry data = row.getGeometry(columnIndexInRowSet);
        value = data.toString();
      } else {
        value = row.getString(columnIndexInRowSet);
      }      
      if (!row.isNull(columnIndexInRowSet)) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        vector.setSafe(currentIndex, bytes);
      }
      currentIndex++;
    }
  }

  /** Non-nullable consumer for var char. */
  static class NonNullableVarCharConsumer extends BaseConsumer<VarCharVector> {

    /** Instantiate a VarCharConsumer. */
    public NonNullableVarCharConsumer(VarCharVector vector, int index) {
      super(vector, index);
    }

    @Override
    public void consume(Row row) throws GSException {
      ContainerInfo conInfo = row.getSchema();
      ColumnInfo colInfo = conInfo.getColumnInfo(columnIndexInRowSet);
      String value = null;
      if (colInfo.getType() == GSType.GEOMETRY) {
        Geometry data = row.getGeometry(columnIndexInRowSet);
        value = data.toString();
      } else {
        value = row.getString(columnIndexInRowSet);
      }      
      byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
      vector.setSafe(currentIndex, bytes);
      currentIndex++;
    }
  }
}
