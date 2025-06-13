/*
    Copyright (c) 2024 TOSHIBA Digital Solutions Corporation
    Copyright (c) The Apache Software Foundation (ASF)

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

package com.toshiba.mwcloud.gs.arrow.adapter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.VectorSchemaRoot;

import com.toshiba.mwcloud.gs.Container;
import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.arrow.adapter.binder.ColumnBinder;

/**
 * A binder binds GridDB JavaAPI prepared statement parameters to rows of Arrow data from a VectorSchemaRoot.
 *
 * Each row of the VectorSchemaRoot will be bound to the configured parameters of the PreparedStatement.
 * One row of data is bound at a time.
 */
public class JavaAPIParameterBinder {
  private final Container<?,Row> container;
  private final VectorSchemaRoot root;
  private final ColumnBinder[] binders;
  private int nextRowIndex;
  private List<Row> rowList;

  /**
   * Create a new parameter binder.
   *
   * @param container
   * @param root The VectorSchemaRoot to pull data from.
   * @param binders Column binders to translate from Arrow data to GridDB JavaAPI parameters, one per parameter.
   * @param parameterIndices For each binder in <tt>binders</tt>, the index of the parameter to bind to.
   */
  private JavaAPIParameterBinder(
      final Container<?,Row> container,
      final VectorSchemaRoot root,
      final ColumnBinder[] binders) {
    this.container = container;
    this.root = root;
    this.binders = binders;
    this.nextRowIndex = 0;
    this.rowList = new ArrayList<Row>();
  }

  /**
   * Initialize a binder with a builder.
   *
   * @param container
   * @param root The {@link VectorSchemaRoot} to pull data from. The binder does not maintain ownership
   *             of the vector schema root.
   */
  public static Builder builder(final Container<?,Row> container, final VectorSchemaRoot root) {
    return new Builder(container, root);
  }

  /** Reset the binder (so the root can be updated with new data). */
  public void reset() {
    nextRowIndex = 0;
  }

  public List<Row> getList()  throws GSException {
    while(next()){}
    return rowList;
  }

  /**
   * Bind the next row of data to the parameters of the row.
   *
   * @return true if a row was bound, false if rows were exhausted
   */
  public boolean next() throws GSException {
    if (nextRowIndex >= root.getRowCount()) {
      return false;
    }
    final Row row = container.createRow();
    for (int i = 0; i < binders.length; i++) {
      binders[i].bind(row, i, nextRowIndex);
    }
    nextRowIndex++;
    rowList.add(row);
    return true;
  }

  /**
   * A builder for a {@link JavaAPIParameterBinder}.
   */
  public static class Builder {
    private final Container<?,Row> container;
    private final VectorSchemaRoot root;
    private final Map<Integer, ColumnBinder> bindings;

    Builder(Container<?,Row> container, VectorSchemaRoot root) {
      this.container = container;
      this.root = root;
      this.bindings = new HashMap<>();
    }

    /** Bind each column to the corresponding parameter in order. */
    public Builder bindAll() {
      for (int i = 0; i < root.getFieldVectors().size(); i++) {
        bind(/*columnIndex=*/ i);
      }
      return this;
    }

    /** Bind the given parameter to the given column using the default binder. */
    public Builder bind(int columnIndex) {
      return bind(
          columnIndex,
          ColumnBinder.forVector(root.getVector(columnIndex)));
    }

    /** Bind the given parameter using the given binder. */
    public Builder bind(int columnIndex, ColumnBinder binder) {
      Preconditions.checkArgument(
          columnIndex >= 0, "columnIndex %d must not be negative", columnIndex);
      bindings.put(columnIndex, binder);
      return this;
    }

    /** Build the binder. */
    public JavaAPIParameterBinder build() {
      ColumnBinder[] binders = new ColumnBinder[bindings.size()];
      int index = 0;
      for (Map.Entry<Integer, ColumnBinder> entry : bindings.entrySet()) {
        binders[index] = entry.getValue();
        index++;
      }
      return new JavaAPIParameterBinder(container, root, binders);
    }
  }
}
