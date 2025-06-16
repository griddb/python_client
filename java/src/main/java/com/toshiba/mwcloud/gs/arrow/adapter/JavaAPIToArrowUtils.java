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

package com.toshiba.mwcloud.gs.arrow.adapter;

import static org.apache.arrow.vector.types.FloatingPointPrecision.DOUBLE;
import static org.apache.arrow.vector.types.FloatingPointPrecision.SINGLE;

import java.io.IOException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

import org.apache.arrow.memory.RootAllocator;
import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.BigIntVector;
import org.apache.arrow.vector.VarBinaryVector;
import org.apache.arrow.vector.BitVector;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.Float4Vector;
import org.apache.arrow.vector.Float8Vector;
import org.apache.arrow.vector.IntVector;
import org.apache.arrow.vector.SmallIntVector;
import org.apache.arrow.vector.TimeStampMilliVector;
import org.apache.arrow.vector.TimeStampMicroVector;
import org.apache.arrow.vector.TimeStampNanoVector;
import org.apache.arrow.vector.TimeStampMilliVector;
import org.apache.arrow.vector.TinyIntVector;
import org.apache.arrow.vector.VarCharVector;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.complex.MapVector;
import org.apache.arrow.vector.types.pojo.ArrowType;
import org.apache.arrow.vector.types.pojo.FieldType;
import org.apache.arrow.vector.util.ValueVectorUtility;
import org.apache.arrow.vector.types.pojo.Schema;
import org.apache.arrow.vector.types.pojo.Field;
import org.apache.arrow.vector.types.pojo.FieldType;
import org.apache.arrow.vector.types.TimeUnit;

import com.toshiba.mwcloud.gs.ContainerInfo;
import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.BitConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.BinaryConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.BigIntConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.CompositeJavaAPIConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.FloatConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.JavaAPIConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.SmallIntConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.IntConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.DoubleConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.TimestampMilliConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.TimestampMicroConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.TimestampNanoConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.TinyIntConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.VarCharConsumer;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.exceptions.JavaAPIConsumerException;

/**
 * Class that does most of the work to convert JavaAPI RowSet data into Arrow columnar format Vector
 * objects.
 *
 * @since 0.10.0
 */
public class JavaAPIToArrowUtils {

  private static final int JAVAAPI_ARRAY_VALUE_COLUMN = 2;

  /** Returns the instance of a {java.util.Calendar} with the UTC time zone and root locale. */
  public static Calendar getUtcCalendar() {
    return Calendar.getInstance(TimeZone.getTimeZone("UTC"), Locale.ROOT);
  }

  /**
   * Create Arrow {@link Schema} object for the given JavaAPI {@link ContainerInfo}.
   *
   * @param containerInfo The ContainerInfo containing the results, to read the JavaAPI metadata from.
   * @param calendar The calendar to use the time zone field of, to construct Timestamp fields from.
   * @return {@link Schema}
   * @throws GSException on error
   */
  public static Schema javaAPIToArrowSchema(ContainerInfo containerInfo, Calendar calendar)
      throws GSException {
    Preconditions.checkNotNull(calendar, "Calendar object can't be null");

    return javaAPIToArrowSchema(containerInfo, new JavaAPIToArrowConfig(new RootAllocator(0), calendar));
  }

 /**
   * Converts the provided JavaAPI type to its respective {@link ArrowType} counterpart.
   *
   * @param fieldInfo the {@link JavaAPIFieldInfo} with information about the original JavaAPI type.
   * @param calendar the {@link Calendar} to use for datetime data types.
   * @return a new {@link ArrowType}.
   */
  public static ArrowType getArrowTypeFromJavaAPIType(
      final JavaAPIFieldInfo fieldInfo, final Calendar calendar) {
    switch (fieldInfo.getGSType()) {
      case BOOL:
        return new ArrowType.Bool();
      case BYTE:
        return new ArrowType.Int(8, true);
      case SHORT:
        return new ArrowType.Int(16, true);
      case INTEGER:
        return new ArrowType.Int(32, true);
      case LONG:
        return new ArrowType.Int(64, true);
      case FLOAT:
        return new ArrowType.FloatingPoint(SINGLE);
      case DOUBLE:
        return new ArrowType.FloatingPoint(DOUBLE);
      case STRING:
      case GEOMETRY:
        return new ArrowType.Utf8();
      case TIMESTAMP:
        final String timezone;
        timezone = null;
        switch  (fieldInfo.getPrecision()) {
            case 1:
                return new ArrowType.Timestamp(TimeUnit.MILLISECOND, timezone);
            case 2:
                return new ArrowType.Timestamp(TimeUnit.MICROSECOND, timezone);
            case 3:
                return new ArrowType.Timestamp(TimeUnit.NANOSECOND, timezone);
        }
      case BLOB:
        return new ArrowType.Binary();
      default:
        // no-op, shouldn't get here
        throw new UnsupportedOperationException("Unmapped GSType type: " + fieldInfo.getGSType());
    }
  }

  /**
   * Create Arrow {@link Schema} object for the given JavaAPI {@link ContainerInfo}.
   *
   * <p>If any columns are of type {@link java.sql.Types#ARRAY}, the configuration object will be
   * used to look up the array sub-type field. The {@link
   * JavaAPIToArrowConfig#getArraySubTypeByColumnIndex(int)} method will be checked first, followed by
   * the {@link JavaAPIToArrowConfig#getArraySubTypeByColumnName(String)} method.
   *
   * @param containerInfo The ContainerInfo containing the results, to read the JavaAPI metadata from.
   * @param config The configuration to use when constructing the schema.
   * @return {@link Schema}
   * @throws GSException on error
   * @throws IllegalArgumentException
   */
  public static Schema javaAPIToArrowSchema(ContainerInfo containerInfo, JavaAPIToArrowConfig config)
      throws GSException {
    Preconditions.checkNotNull(containerInfo, "JavaAPI ContainerInfo object can't be null");
    Preconditions.checkNotNull(config, "The configuration object must not be null");

    List<Field> fields = new ArrayList<>();
    int columnCount = containerInfo.getColumnCount();
    for (int i = 0; i < columnCount; i++) {
      final String columnName = containerInfo.getColumnInfo(i).getName();

      final Map<String, String> columnMetadata =
          config.getColumnMetadataByColumnIndex() != null
              ? config.getColumnMetadataByColumnIndex().get(i)
              : null;
      final Map<String, String> metadata;
      if (columnMetadata != null && !columnMetadata.isEmpty()) {
        metadata = columnMetadata;
      } else {
        metadata = null;
      }

      final JavaAPIFieldInfo columnFieldInfo = getJavaAPIFieldInfoForColumn(containerInfo, i, config);
      final ArrowType arrowType = config.getJavaAPIToArrowTypeConverter().apply(columnFieldInfo);
      if (arrowType != null) {
        final FieldType fieldType =
            new FieldType(
                isColumnNullable(containerInfo, i, columnFieldInfo),
                arrowType, /* dictionary encoding */
                null,
                metadata);

        List<Field> children = null;
        if (arrowType.getTypeID() == ArrowType.List.TYPE_TYPE) {
          final JavaAPIFieldInfo arrayFieldInfo = getJavaAPIFieldInfoForArraySubType(containerInfo, i, config);
          if (arrayFieldInfo == null) {
            throw new IllegalArgumentException(
                "Configuration does not provide a mapping for array column " + i);
          }
          children = new ArrayList<Field>();
          final ArrowType childType = config.getJavaAPIToArrowTypeConverter().apply(arrayFieldInfo);
          children.add(new Field("child", FieldType.nullable(childType), null));
        } else if (arrowType.getTypeID() == ArrowType.ArrowTypeID.Map) {
          FieldType mapType = new FieldType(false, ArrowType.Struct.INSTANCE, null, null);
          FieldType keyType = new FieldType(false, new ArrowType.Utf8(), null, null);
          FieldType valueType = new FieldType(false, new ArrowType.Utf8(), null, null);
          children = new ArrayList<>();
          children.add(
              new Field(
                  "child",
                  mapType,
                  Arrays.asList(
                      new Field(MapVector.KEY_NAME, keyType, null),
                      new Field(MapVector.VALUE_NAME, valueType, null))));
        }

        fields.add(new Field(columnName, fieldType, children));
      }
    }
    return new Schema(fields, config.getSchemaMetadata());
  }

  static JavaAPIFieldInfo getJavaAPIFieldInfoForColumn(
      ContainerInfo containerInfo, int arrayColumn, JavaAPIToArrowConfig config) throws GSException {
    Preconditions.checkNotNull(containerInfo, "ContainerInfo object cannot be null");
    Preconditions.checkNotNull(config, "Configuration must not be null");
    Preconditions.checkArgument(
        arrayColumn >= 0, "ContainerInfo columns start with 1; column cannot be less than 1");
    Preconditions.checkArgument(
        arrayColumn < containerInfo.getColumnCount(),
        "Column number cannot be more than the number of columns");

    JavaAPIFieldInfo fieldInfo = config.getExplicitTypeByColumnIndex(arrayColumn);
    if (fieldInfo == null) {
      fieldInfo = config.getExplicitTypeByColumnName(containerInfo.getColumnInfo(arrayColumn).getName());
    }
    if (fieldInfo != null) {
      return fieldInfo;
    }
    return new JavaAPIFieldInfo(containerInfo, arrayColumn);
  }

  /* Uses the configuration to determine what the array sub-type JavaAPIFieldInfo is.
   * If no sub-type can be found, returns null.
   */
  private static JavaAPIFieldInfo getJavaAPIFieldInfoForArraySubType(
      ContainerInfo containerInfo, int arrayColumn, JavaAPIToArrowConfig config) throws GSException {

    Preconditions.checkNotNull(containerInfo, "ContainerInfo object cannot be null");
    Preconditions.checkNotNull(config, "Configuration must not be null");
    Preconditions.checkArgument(
        arrayColumn > 0, "ContainerInfo columns start with 1; column cannot be less than 1");
    Preconditions.checkArgument(
        arrayColumn <= containerInfo.getColumnCount(),
        "Column number cannot be more than the number of columns");

    JavaAPIFieldInfo fieldInfo = config.getArraySubTypeByColumnIndex(arrayColumn);
    if (fieldInfo == null) {
      fieldInfo = config.getArraySubTypeByColumnName(containerInfo.getColumnInfo(arrayColumn).getName());
    }
    return fieldInfo;
  }

  /**
   * Iterate the given JavaAPI {@link com.toshiba.mwcloud.gs.RowSet} object to fetch the data and transpose it to populate
   * the given Arrow Vector objects.
   *
   * @param rowSet RowSet to use to fetch the data from underlying database
   * @param root Arrow {@link VectorSchemaRoot} object to populate
   * @param calendar The calendar to use when reading {@link java.sql.Date}, {@link java.sql.Time}, or {@link
   *     Timestamp} data types from the {@link com.toshiba.mwcloud.gs.RowSet}, or <code>null</code> if not converting.
   * @throws GSException on error
   */
  public static void javaAPIToArrowVectors(RowSet<Row> rowSet, VectorSchemaRoot root, Calendar calendar)
      throws GSException, IOException {

    Preconditions.checkNotNull(calendar, "Calendar object can't be null");

    javaAPIToArrowVectors(rowSet, root, new JavaAPIToArrowConfig(new RootAllocator(0), calendar));
  }

  static boolean isColumnNullable(
  	  ContainerInfo containerInfo, int index, JavaAPIFieldInfo info) throws GSException {
    int nullableValue;
    if (info != null) {
      nullableValue = info.isNullable();
    } else {
      if (containerInfo.getColumnInfo(index).getNullable()) {
        nullableValue = 1;
      } else {
        nullableValue = 0;
      }
    }
    return nullableValue == 1;
}


  /**
   * Iterate the given JavaAPI {@link RowSet} object to fetch the data and transpose it to populate
   * the given Arrow Vector objects.
   *
   * @param rowSet RowSet to use to fetch the data from underlying database
   * @param root Arrow {@link VectorSchemaRoot} object to populate
   * @param config The configuration to use when reading the data.
   * @throws GSException on error
   * @throws JavaAPIConsumerException on error from VectorConsumer
   */
  public static void javaAPIToArrowVectors(
      RowSet<Row> rowSet, VectorSchemaRoot root, JavaAPIToArrowConfig config)
      throws GSException, IOException {

    ContainerInfo containerInfo = rowSet.getSchema();
    int columnCount = containerInfo.getColumnCount();

    JavaAPIConsumer[] consumers = new JavaAPIConsumer[columnCount];
    for (int i = 0; i < columnCount; i++) {
      FieldVector vector = root.getVector(containerInfo.getColumnInfo(i).getName());
      final JavaAPIFieldInfo columnFieldInfo = getJavaAPIFieldInfoForColumn(containerInfo, i, config);
      consumers[i] =
          getConsumer(
              vector.getField().getType(),
              i,
              isColumnNullable(containerInfo, i, columnFieldInfo),
              vector,
              config);
    }

    CompositeJavaAPIConsumer compositeConsumer = null;
    // Only clean resources when occurs error,
    // vectors within consumers are useful and users are responsible for its close.
    try {
      compositeConsumer = new CompositeJavaAPIConsumer(consumers);
      int readRowCount = 0;
      if (config.getTargetBatchSize() == JavaAPIToArrowConfig.NO_LIMIT_BATCH_SIZE) {
        while (rowSet.hasNext()) {
          Row row = rowSet.next();
          ValueVectorUtility.ensureCapacity(root, readRowCount + 1);
          compositeConsumer.consume(row);
          readRowCount++;
        }
      } else {
        while (readRowCount < config.getTargetBatchSize() && rowSet.hasNext()) {
          Row row = rowSet.next();
          compositeConsumer.consume(row);
          readRowCount++;
        }
      }

      root.setRowCount(readRowCount);
    } catch (Exception e) {
      // error occurs and clean up resources.
      if (compositeConsumer != null) {
        compositeConsumer.close();
      }
      throw e;
    }
  }

  /**
   * Default function used for JavaAPIConsumerFactory. This function gets a JavaAPIConsumer for the given
   * column based on the Arrow type and provided vector.
   *
   * @param arrowType Arrow type for the column.
   * @param columnIndex Column index to fetch from the RowSet
   * @param nullable Whether the value is nullable or not
   * @param vector Vector to store the consumed value
   * @param config Associated JavaAPIToArrowConfig, used mainly for the Calendar.
   * @return {@link JavaAPIConsumer}
   */
  public static JavaAPIConsumer getConsumer(
      ArrowType arrowType,
      int columnIndex,
      boolean nullable,
      FieldVector vector,
      JavaAPIToArrowConfig config) {
    final Calendar calendar = config.getCalendar();

    switch (arrowType.getTypeID()) {
      case Bool:
        return BitConsumer.createConsumer((BitVector) vector, columnIndex, nullable);
      case Int:
        switch (((ArrowType.Int) arrowType).getBitWidth()) {
          case 8:
            return TinyIntConsumer.createConsumer((TinyIntVector) vector, columnIndex, nullable);
          case 16:
            return SmallIntConsumer.createConsumer((SmallIntVector) vector, columnIndex, nullable);
          case 32:
            return IntConsumer.createConsumer((IntVector) vector, columnIndex, nullable);
          case 64:
            return BigIntConsumer.createConsumer((BigIntVector) vector, columnIndex, nullable);
          default:
            return null;
        }
      case FloatingPoint:
        switch (((ArrowType.FloatingPoint) arrowType).getPrecision()) {
          case SINGLE:
            return FloatConsumer.createConsumer((Float4Vector) vector, columnIndex, nullable);
          case DOUBLE:
            return DoubleConsumer.createConsumer((Float8Vector) vector, columnIndex, nullable);
          default:
            return null;
        }
      case Utf8:
        return VarCharConsumer.createConsumer((VarCharVector) vector, columnIndex, nullable);
      case Binary:
        return BinaryConsumer.createConsumer((VarBinaryVector) vector, columnIndex, nullable);
      case Timestamp:
        TimeUnit timeUnit = ((ArrowType.Timestamp)arrowType).getUnit();
        switch (timeUnit) {
          case MILLISECOND:
            return TimestampMilliConsumer.createConsumer(
                        (TimeStampMilliVector) vector, columnIndex, nullable);
          case MICROSECOND:
            return TimestampMicroConsumer.createConsumer(
                        (TimeStampMicroVector) vector, columnIndex, nullable);
          case NANOSECOND:
            return TimestampNanoConsumer.createConsumer(
                        (TimeStampNanoVector) vector, columnIndex, nullable);
        }
      default:
        // no-op, shouldn't get here
        throw new UnsupportedOperationException("No consumer for Arrow type: " + arrowType);
    }
  }
}
