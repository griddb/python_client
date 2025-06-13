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

import java.math.RoundingMode;
import java.util.Calendar;
import java.util.Map;
import java.util.function.Function;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.types.pojo.ArrowType;

import com.toshiba.mwcloud.gs.arrow.adapter.consumer.JavaAPIConsumer;

/**
 * This class configures the JavaAPI-to-Arrow conversion process.
 *
 * <p>The allocator is used to construct the {@link org.apache.arrow.vector.VectorSchemaRoot}, and
 * the calendar is used to define the time zone of any {@link
 * org.apache.arrow.vector.types.pojo.ArrowType.Timestamp} fields that are created during the
 * conversion. Neither field may be <code>null</code>.
 *
 * <p>If the <code>includeMetadata</code> flag is set, the Arrow field metadata will contain
 * information from the corresponding {@link com.toshiba.mwcloud.gs.ContainerInfo} that was used to create the
 * {@link org.apache.arrow.vector.types.pojo.FieldType} of the corresponding {@link
 * org.apache.arrow.vector.FieldVector}.
 */
public final class JavaAPIToArrowConfig {

  public static final int DEFAULT_TARGET_BATCH_SIZE = 1024;
  public static final int NO_LIMIT_BATCH_SIZE = -1;
  private final Calendar calendar;
  private final BufferAllocator allocator;
  private final boolean includeMetadata;
  private final boolean reuseVectorSchemaRoot;
  private final Map<Integer, JavaAPIFieldInfo> arraySubTypesByColumnIndex;
  private final Map<String, JavaAPIFieldInfo> arraySubTypesByColumnName;
  private final Map<Integer, JavaAPIFieldInfo> explicitTypesByColumnIndex;
  private final Map<String, JavaAPIFieldInfo> explicitTypesByColumnName;
  private final Map<String, String> schemaMetadata;
  private final Map<Integer, Map<String, String>> columnMetadataByColumnIndex;
  private final RoundingMode bigDecimalRoundingMode;
  /**
   * The maximum rowCount to read each time when partially convert data. Default value is 1024 and
   * -1 means disable partial read. default is -1 which means disable partial read. Note that this
   * flag only useful for {@link JavaAPIToArrow#JavaToArrowVectorIterator} 1) if targetBatchSize != -1,
   * it will convert full data into multiple vectors with valueCount no more than targetBatchSize.
   * 2) if targetBatchSize == -1, it will convert full data into a single vector in {@link
   * ArrowVectorIterator}
   */
  private final int targetBatchSize;

  private final Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter;
  private final JavaAPIConsumerFactory javaAPIConsumerGetter;

  /**
   * Constructs a new configuration from the provided allocator and calendar. The <code>allocator
   * </code> is used when constructing the Arrow vectors from the ResultSet, and the calendar is
   * used to define Arrow Timestamp fields, and to read time-based fields from the JavaAPI <code>
   * ResultSet</code>.
   *
   * @param allocator The memory allocator to construct the Arrow vectors with.
   * @param calendar The calendar to use when constructing Timestamp fields and reading time-based
   *     results.
   */
  JavaAPIToArrowConfig(BufferAllocator allocator, Calendar calendar) {
    this(
        allocator,
        calendar,
        /* include metadata */ false,
        /* reuse vector schema root */ false,
        /* array sub-types by column index */ null,
        /* array sub-types by column name */ null,
        DEFAULT_TARGET_BATCH_SIZE,
        null,
        null);
  }

  JavaAPIToArrowConfig(
      BufferAllocator allocator,
      Calendar calendar,
      boolean includeMetadata,
      boolean reuseVectorSchemaRoot,
      Map<Integer, JavaAPIFieldInfo> arraySubTypesByColumnIndex,
      Map<String, JavaAPIFieldInfo> arraySubTypesByColumnName,
      int targetBatchSize,
      Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter) {
    this(
        allocator,
        calendar,
        includeMetadata,
        reuseVectorSchemaRoot,
        arraySubTypesByColumnIndex,
        arraySubTypesByColumnName,
        targetBatchSize,
        javaAPIToArrowTypeConverter,
        null);
  }

  /**
   * Constructs a new configuration from the provided allocator and calendar. The <code>allocator
   * </code> is used when constructing the Arrow vectors from the ResultSet, and the calendar is
   * used to define Arrow Timestamp fields, and to read time-based fields from the JavaAPI <code>
   * ResultSet</code>.
   *
   * @param allocator The memory allocator to construct the Arrow vectors with.
   * @param calendar The calendar to use when constructing Timestamp fields and reading time-based
   *     results.
   * @param includeMetadata Whether to include JavaAPI field metadata in the Arrow Schema Field
   *     metadata.
   * @param reuseVectorSchemaRoot Whether to reuse the vector schema root for each data load.
   * @param arraySubTypesByColumnIndex
   * @param arraySubTypesByColumnName
   * @param targetBatchSize The target batch size to be used in preallocation of the resulting
   *     vectors.
   * @param javaAPIToArrowTypeConverter The function that maps JavaAPI field type information to arrow
   *     type. If set to null, the default mapping will be used, which is defined as:
   *     <ul>
   *       <li>CHAR --> ArrowType.Utf8
   *       <li>NCHAR --> ArrowType.Utf8
   *       <li>VARCHAR --> ArrowType.Utf8
   *       <li>NVARCHAR --> ArrowType.Utf8
   *       <li>LONGVARCHAR --> ArrowType.Utf8
   *       <li>LONGNVARCHAR --> ArrowType.Utf8
   *       <li>NUMERIC --> ArrowType.Decimal(precision, scale)
   *       <li>DECIMAL --> ArrowType.Decimal(precision, scale)
   *       <li>BIT --> ArrowType.Bool
   *       <li>TINYINT --> ArrowType.Int(8, signed)
   *       <li>SMALLINT --> ArrowType.Int(16, signed)
   *       <li>INTEGER --> ArrowType.Int(32, signed)
   *       <li>BIGINT --> ArrowType.Int(64, signed)
   *       <li>REAL --> ArrowType.FloatingPoint(FloatingPointPrecision.SINGLE)
   *       <li>FLOAT --> ArrowType.FloatingPoint(FloatingPointPrecision.SINGLE)
   *       <li>DOUBLE --> ArrowType.FloatingPoint(FloatingPointPrecision.DOUBLE)
   *       <li>BINARY --> ArrowType.Binary
   *       <li>VARBINARY --> ArrowType.Binary
   *       <li>LONGVARBINARY --> ArrowType.Binary
   *       <li>DATE --> ArrowType.Date(DateUnit.DAY)
   *       <li>TIME --> ArrowType.Time(TimeUnit.MILLISECOND, 32)
   *       <li>TIMESTAMP --> ArrowType.Timestamp(TimeUnit.MILLISECOND, calendar timezone)
   *       <li>CLOB --> ArrowType.Utf8
   *       <li>BLOB --> ArrowType.Binary
   *       <li>ARRAY --> ArrowType.List
   *       <li>STRUCT --> ArrowType.Struct
   *       <li>NULL --> ArrowType.Null
   *     </ul>
   *
   * @param bigDecimalRoundingMode
   */
  JavaAPIToArrowConfig(
      BufferAllocator allocator,
      Calendar calendar,
      boolean includeMetadata,
      boolean reuseVectorSchemaRoot,
      Map<Integer, JavaAPIFieldInfo> arraySubTypesByColumnIndex,
      Map<String, JavaAPIFieldInfo> arraySubTypesByColumnName,
      int targetBatchSize,
      Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter,
      RoundingMode bigDecimalRoundingMode) {

    this(
        allocator,
        calendar,
        includeMetadata,
        reuseVectorSchemaRoot,
        arraySubTypesByColumnIndex,
        arraySubTypesByColumnName,
        targetBatchSize,
        javaAPIToArrowTypeConverter,
        null,
        null,
        null,
        null,
        bigDecimalRoundingMode);
  }

  JavaAPIToArrowConfig(
      BufferAllocator allocator,
      Calendar calendar,
      boolean includeMetadata,
      boolean reuseVectorSchemaRoot,
      Map<Integer, JavaAPIFieldInfo> arraySubTypesByColumnIndex,
      Map<String, JavaAPIFieldInfo> arraySubTypesByColumnName,
      int targetBatchSize,
      Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter,
      Map<Integer, JavaAPIFieldInfo> explicitTypesByColumnIndex,
      Map<String, JavaAPIFieldInfo> explicitTypesByColumnName,
      Map<String, String> schemaMetadata,
      Map<Integer, Map<String, String>> columnMetadataByColumnIndex,
      RoundingMode bigDecimalRoundingMode) {
    this(
        allocator,
        calendar,
        includeMetadata,
        reuseVectorSchemaRoot,
        arraySubTypesByColumnIndex,
        arraySubTypesByColumnName,
        targetBatchSize,
        javaAPIToArrowTypeConverter,
        null,
        explicitTypesByColumnIndex,
        explicitTypesByColumnName,
        schemaMetadata,
        columnMetadataByColumnIndex,
        bigDecimalRoundingMode);
  }

  JavaAPIToArrowConfig(
      BufferAllocator allocator,
      Calendar calendar,
      boolean includeMetadata,
      boolean reuseVectorSchemaRoot,
      Map<Integer, JavaAPIFieldInfo> arraySubTypesByColumnIndex,
      Map<String, JavaAPIFieldInfo> arraySubTypesByColumnName,
      int targetBatchSize,
      Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter,
      JavaAPIConsumerFactory javaAPIConsumerGetter,
      Map<Integer, JavaAPIFieldInfo> explicitTypesByColumnIndex,
      Map<String, JavaAPIFieldInfo> explicitTypesByColumnName,
      Map<String, String> schemaMetadata,
      Map<Integer, Map<String, String>> columnMetadataByColumnIndex,
      RoundingMode bigDecimalRoundingMode) {
    Preconditions.checkNotNull(allocator, "Memory allocator cannot be null");
    this.allocator = allocator;
    this.calendar = calendar;
    this.includeMetadata = includeMetadata;
    this.reuseVectorSchemaRoot = reuseVectorSchemaRoot;
    this.arraySubTypesByColumnIndex = arraySubTypesByColumnIndex;
    this.arraySubTypesByColumnName = arraySubTypesByColumnName;
    this.targetBatchSize = targetBatchSize;
    this.explicitTypesByColumnIndex = explicitTypesByColumnIndex;
    this.explicitTypesByColumnName = explicitTypesByColumnName;
    this.schemaMetadata = schemaMetadata;
    this.columnMetadataByColumnIndex = columnMetadataByColumnIndex;
    this.bigDecimalRoundingMode = bigDecimalRoundingMode;

    // set up type converter
    this.javaAPIToArrowTypeConverter =
        javaAPIToArrowTypeConverter != null
            ? javaAPIToArrowTypeConverter
            : (javaAPIFieldInfo) -> JavaAPIToArrowUtils.getArrowTypeFromJavaAPIType(javaAPIFieldInfo, calendar);

    this.javaAPIConsumerGetter =
        javaAPIConsumerGetter != null ? javaAPIConsumerGetter : JavaAPIToArrowUtils::getConsumer;
  }

  /**
   * The calendar to use when defining Arrow Timestamp fields and retrieving {@link java.sql.Date},
   * {@link java.sql.Time}, or {@link java.sql.Timestamp} data types from the {@link
   * com.toshiba.mwcloud.gs.RowSet}, or <code>null</code> if not converting.
   *
   * @return the calendar.
   */
  public Calendar getCalendar() {
    return calendar;
  }

  /**
   * The Arrow memory allocator.
   *
   * @return the allocator.
   */
  public BufferAllocator getAllocator() {
    return allocator;
  }

  /**
   * Whether to include JavaAPI RowSet field metadata in the Arrow Schema field metadata.
   *
   * @return <code>true</code> to include field metadata, <code>false</code> to exclude it.
   */
  public boolean shouldIncludeMetadata() {
    return includeMetadata;
  }

  /** Get the target batch size for partial read. */
  public int getTargetBatchSize() {
    return targetBatchSize;
  }

  /** Get whether it is allowed to reuse the vector schema root. */
  public boolean isReuseVectorSchemaRoot() {
    return reuseVectorSchemaRoot;
  }

  /** Gets the mapping between JavaAPI type information to Arrow type. */
  public Function<JavaAPIFieldInfo, ArrowType> getJavaAPIToArrowTypeConverter() {
    return javaAPIToArrowTypeConverter;
  }

  /** Gets the JavaAPI consumer getter. */
  public JavaAPIConsumerFactory getJavaAPIConsumerGetter() {
    return javaAPIConsumerGetter;
  }

  /**
   * Returns the array sub-type {@link JavaAPIFieldInfo} defined for the provided column index.
   *
   * @param index
   * @return The {@link JavaAPIFieldInfo} for that array's sub-type, or <code>null</code> if not
   *     defined.
   */
  public JavaAPIFieldInfo getArraySubTypeByColumnIndex(int index) {
    if (arraySubTypesByColumnIndex == null) {
      return null;
    } else {
      return arraySubTypesByColumnIndex.get(index);
    }
  }

  /**
   * Returns the array sub-type {@link JavaAPIFieldInfo} defined for the provided column name.
   *
   * @param name
   * @return The {@link JavaAPIFieldInfo} for that array's sub-type, or <code>null</code> if not
   *     defined.
   */
  public JavaAPIFieldInfo getArraySubTypeByColumnName(String name) {
    if (arraySubTypesByColumnName == null) {
      return null;
    } else {
      return arraySubTypesByColumnName.get(name);
    }
  }

  /**
   * Returns the type {@link JavaAPIFieldInfo} explicitly defined for the provided column index.
   *
   * @param index The {@link com.toshiba.mwcloud.gs.ContainerInfo} column index to evaluate for explicit type
   *     mapping.
   * @return The {@link JavaAPIFieldInfo} defined for the column, or <code>null</code> if not defined.
   */
  public JavaAPIFieldInfo getExplicitTypeByColumnIndex(int index) {
    if (explicitTypesByColumnIndex == null) {
      return null;
    } else {
      return explicitTypesByColumnIndex.get(index);
    }
  }

  /**
   * Returns the type {@link JavaAPIFieldInfo} explicitly defined for the provided column name.
   *
   * @param name The {@link com.toshiba.mwcloud.gs.ContainerInfo} column name to evaluate for explicit type
   *     mapping.
   * @return The {@link JavaAPIFieldInfo} defined for the column, or <code>null</code> if not defined.
   */
  public JavaAPIFieldInfo getExplicitTypeByColumnName(String name) {
    if (explicitTypesByColumnName == null) {
      return null;
    } else {
      return explicitTypesByColumnName.get(name);
    }
  }

  /** Return schema level metadata or null if not provided. */
  public Map<String, String> getSchemaMetadata() {
    return schemaMetadata;
  }

  /** Return metadata from columnIndex->meta map on per field basis or null if not provided. */
  public Map<Integer, Map<String, String>> getColumnMetadataByColumnIndex() {
    return columnMetadataByColumnIndex;
  }

  public RoundingMode getBigDecimalRoundingMode() {
    return bigDecimalRoundingMode;
  }

  /** Interface for a function that gets a JavaAPI consumer for the given values. */
  @FunctionalInterface
  public interface JavaAPIConsumerFactory {
    JavaAPIConsumer apply(
        ArrowType arrowType,
        int columnIndex,
        boolean nullable,
        FieldVector vector,
        JavaAPIToArrowConfig config);
  }
}
