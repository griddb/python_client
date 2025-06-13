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
import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.ColumnInfo;
import com.toshiba.mwcloud.gs.TimeUnit;
import com.toshiba.mwcloud.gs.GSException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.Calendar;
import org.apache.arrow.vector.TimeStampVector;
import org.apache.arrow.vector.types.pojo.ArrowType;

/** A column binder for timestamps. */
public class TimeStampBinder extends BaseColumnBinder<TimeStampVector> {
  private final Calendar calendar;
  private final long unitsPerSecond;
  private final long nanosPerUnit;

  /** Create a binder for a timestamp vector using the default GS type code. */
  public TimeStampBinder(TimeStampVector vector, Calendar calendar) {
    this(
        vector,
        calendar,
        GSType.TIMESTAMP);
  }

  /**
   * Create a binder for a timestamp vector.
   *
   * @param vector The vector to pull values from.
   * @param calendar Optionally, the calendar to pass to GridDB.
   * @param gsType The GS type code to use for null values.
   */
  public TimeStampBinder(TimeStampVector vector, Calendar calendar, GSType gsType) {
    super(vector, gsType);
    this.calendar = calendar;

    final ArrowType.Timestamp type = (ArrowType.Timestamp) vector.getField().getType();
    switch (type.getUnit()) {
      case SECOND:
        this.unitsPerSecond = 1;
        this.nanosPerUnit = 1_000_000_000;
        break;
      case MILLISECOND:
        this.unitsPerSecond = 1_000;
        this.nanosPerUnit = 1_000_000;
        break;
      case MICROSECOND:
        this.unitsPerSecond = 1_000_000;
        this.nanosPerUnit = 1_000;
        break;
      case NANOSECOND:
        this.unitsPerSecond = 1_000_000_000;
        this.nanosPerUnit = 1;
        break;
      default:
        throw new IllegalArgumentException("Invalid time unit in " + type);
    }
  }

  @Override
  public void bind(Row row, int columnIndex, int rowIndex)
      throws GSException {
    final long rawValue =
        vector.getDataBuffer().getLong((long) rowIndex * TimeStampVector.TYPE_WIDTH);
    final long seconds = rawValue / unitsPerSecond;
    final int nanos = (int) ((rawValue - (seconds * unitsPerSecond)) * nanosPerUnit);
    final Timestamp value = new Timestamp(seconds * 1_000);
    value.setNanos(nanos);

    ContainerInfo conInfo = row.getSchema();
    ColumnInfo colInfo = conInfo.getColumnInfo(columnIndex);
    TimeUnit timeUnit = colInfo.getTimePrecision();

    if (calendar != null) {
      // Timestamp == Date == UTC timestamp (confusingly). Arrow's timestamp with timezone is a UTC
      // value with a
      // zone offset, so we don't need to do any conversion.
      if (timeUnit == TimeUnit.MICROSECOND || timeUnit == TimeUnit.NANOSECOND) {
        row.setPreciseTimestamp(columnIndex, value);
      } else {
        row.setTimestamp(columnIndex, value);
      }

    } else {
      // Arrow timestamp without timezone isn't strictly convertible to any timezone. So this is
      // technically wrong,
      // but there is no 'correct' interpretation here. The application should provide a calendar.
      if (timeUnit == TimeUnit.MICROSECOND || timeUnit == TimeUnit.NANOSECOND) { 
        row.setPreciseTimestamp(columnIndex, value);
      } else {
        row.setTimestamp(columnIndex, value);
      }
    }
  }

  private static boolean isZoned(ArrowType type) {
    final String timezone = ((ArrowType.Timestamp) type).getTimezone();
    return timezone != null && !timezone.isEmpty();
  }
}
