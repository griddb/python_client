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

import org.apache.arrow.util.Preconditions;

import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.TimeUnit;
import com.toshiba.mwcloud.gs.GSType;

/**
 * This class represents the information about a GridDB JavaAPI ResultSet Field that is
 * needed to construct an {@link org.apache.arrow.vector.types.pojo.ArrowType}.
 * Currently, this is:
 * <ul>
 *   <li>The GridDB JavaAPI {@link com.toshiba.mwcloud.gs.GSType} type.</li>
 *   <li>The nullability.</li>
 *   <li>The field's precision (used for {@link com.toshiba.mwcloud.gs.GSType#TIMESTAMP} type).</li>
 * </ul>
 */
public class JavaAPIFieldInfo {
  private final int column;
  private final GSType type;
  private final int nullability;
  private final int precision;
  private final int scale;
  private final String typeName;
  private final int displaySize;

  /**
   * Builds a <code>JavaAPIFieldInfo</code> using only the {@link com.toshiba.mwcloud.gs.GSType} type. the precision and
   * scale will be set to <code>0</code>.
   *
   * @param type The {@link com.toshiba.mwcloud.gs.GSType} type.
   * @throws IllegalArgumentException if GSType is {@link com.toshiba.mwcloud.gs.GSType#TIMESTAMP}.
   */
  public JavaAPIFieldInfo(GSType type) {
    Preconditions.checkArgument(
        (type == GSType.TIMESTAMP),
        "TIMESTAMP types require a precision; please use another constructor.");
    this.column = 0;
    this.type = type;
    this.nullability = 2; //ResultSetMetaData.columnNullableUnknown;
    this.precision = 0;
    this.scale = 0;
    this.typeName = "";
    this.displaySize = 0;
  }

  /**
   * Builds a <code>JavaAPIFieldInfo</code> from the {@link com.toshiba.mwcloud.gs.GSType} type, precision, and scale.
   *
   * @param type The {@link com.toshiba.mwcloud.gs.GSType} type.
   * @param precision
   * @param scale
   */
  public JavaAPIFieldInfo(GSType type, int precision, int scale) {
    this.column = 0;
    this.type = type;
    this.nullability = 2; //ResultSetMetaData.columnNullableUnknown;
    this.precision = precision;
    this.scale = scale;
    this.typeName = "";
    this.displaySize = 0;
  }

  /**
   * Builds a <code>JavaAPIFieldInfo</code> from the {@link com.toshiba.mwcloud.gs.GSType} type, nullability, precision, and scale.
   *
   * @param type The {@link com.toshiba.mwcloud.gs.GSType} type.
   * @param nullability
   * @param precision
   * @param scale
   */
  public JavaAPIFieldInfo(GSType type, int nullability, int precision, int scale) {
    this.column = 0;
    this.type = type;
    this.nullability = nullability;
    this.precision = precision;
    this.scale = scale;
    this.typeName = "";
    this.displaySize = 0;
  }

  /**
   * Builds a <code>JavaAPIFieldInfo</code> from the corresponding {@link com.toshiba.mwcloud.gs.ContainerInfo} column.
   *
   * @param conInfo The {@link com.toshiba.mwcloud.gs.ContainerInfo} to get the field information from.
   * @param column The column to get the field information for (on a 1-based index).
   * @throws GSException If the column information cannot be retrieved.
   * @throws NullPointerException if <code>rsmd</code> is <code>null</code>.
   * @throws IllegalArgumentException if <code>column</code> is out of bounds.
   */
  public JavaAPIFieldInfo(ContainerInfo conInfo, int column) throws GSException {
    Preconditions.checkArgument(column >= 0, "ContainerInfo columns have indices starting at 1.");
    Preconditions.checkArgument(
        column < conInfo.getColumnCount(),
        "The index must be within the number of columns (1 to %s, inclusive)", conInfo.getColumnCount());

    this.column = column;
  	this.type = conInfo.getColumnInfo(column).getType();
  	if (conInfo.getColumnInfo(column).getNullable()) {
  		this.nullability = 1;
  	} else {
  		this.nullability = 0;
  	}
  	if (conInfo.getColumnInfo(column).getType() == GSType.TIMESTAMP) {
            TimeUnit timeUnit = conInfo.getColumnInfo(column).getTimePrecision();
            switch  (timeUnit) {
                case MILLISECOND:
  	            this.precision = 1;
                    break;
                case MICROSECOND:
  	            this.precision = 2;
                    break;
                case NANOSECOND:
  	            this.precision = 3;
                    break;
                default:
                    this.precision = 0;
            }
  	} else {
            this.precision = 0;
        }
        
    this.scale = 0;
    this.typeName = conInfo.getColumnInfo(column).getName();
    this.displaySize = 131072;
  }

  /**
   * The {@link com.toshiba.mwcloud.gs.GSType} type.
   */
  public GSType getGSType() {
    return type;
  }

  /**
   * The nullability.
   */
  public int isNullable() {
    return nullability;
  }

  /**
   * The time precision, for {@link com.toshiba.mwcloud.gs.GSType#TIMESTAMP} type.
   */
  public int getPrecision() {
    return precision;
  }

  /**
   * The numeric scale.
   */
  public int getScale() {
    return scale;
  }

  /**
   * The column index for query column.
   */
  public int getColumn() {
    return column;
  }

  /**
   * The type name as reported by the database.
   */
  public String getTypeName() {
    return typeName;
  }

  /**
   * The max number of characters for the column.
   */
  public int getDisplaySize() {
    return displaySize;
  }
}
