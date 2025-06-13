/*
 * Copyright (c) 2024 TOSHIBA Digital Solutions Corporation
 * Copyright (c) The Apache Software Foundation (ASF)

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.toshiba.mwcloud.gs.arrow.adapter;

import static com.toshiba.mwcloud.gs.arrow.adapter.JavaAPIToArrowConfig.DEFAULT_TARGET_BATCH_SIZE;

import java.math.RoundingMode;
import java.util.Calendar;
import java.util.Map;
import java.util.function.Function;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.types.pojo.ArrowType;

/** This class builds {@link JavaAPIToArrowConfig}s. */
public class JavaAPIToArrowConfigBuilder {
  private Calendar calendar;
  private BufferAllocator allocator;
  private boolean includeMetadata;
  private boolean reuseVectorSchemaRoot;
  private Map<Integer, JavaAPIFieldInfo> arraySubTypesByColumnIndex;
  private Map<String, JavaAPIFieldInfo> arraySubTypesByColumnName;
  private Map<Integer, JavaAPIFieldInfo> explicitTypesByColumnIndex;
  private Map<String, JavaAPIFieldInfo> explicitTypesByColumnName;
  private Map<String, String> schemaMetadata;
  private Map<Integer, Map<String, String>> columnMetadataByColumnIndex;
  private int targetBatchSize;
  private Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter;
  private JavaAPIToArrowConfig.JavaAPIConsumerFactory javaAPIConsumerGetter;
  private RoundingMode bigDecimalRoundingMode;

  /**
   * Default constructor for the <code>JavaAPIToArrowConfigBuilder}</code>. Use the setter methods for
   * the allocator and calendar; the allocator must be set. Otherwise, {@link #build()} will throw a
   * {@link NullPointerException}.
   */
  public JavaAPIToArrowConfigBuilder() {
    this.allocator = null;
    this.calendar = null;
    this.includeMetadata = false;
    this.reuseVectorSchemaRoot = false;
    this.arraySubTypesByColumnIndex = null;
    this.arraySubTypesByColumnName = null;
    this.explicitTypesByColumnIndex = null;
    this.explicitTypesByColumnName = null;
    this.schemaMetadata = null;
    this.columnMetadataByColumnIndex = null;
    this.bigDecimalRoundingMode = null;
  }

  /**
   * Constructor for the <code>JavaAPIToArrowConfigBuilder</code>. The allocator is required, and a
   * {@link NullPointerException} will be thrown if it is <code>null</code>.
   *
   * <p>The allocator is used to construct Arrow vectors from the JavaAPI ResultSet. The calendar is
   * used to determine the time zone of {@link java.sql.Timestamp} fields and convert {@link
   * java.sql.Date}, {@link java.sql.Time}, and {@link java.sql.Timestamp} fields to a single,
   * common time zone when reading from the result set.
   *
   * @param allocator The Arrow Vector memory allocator.
   * @param calendar The calendar to use when constructing timestamp fields.
   */
  public JavaAPIToArrowConfigBuilder(BufferAllocator allocator, Calendar calendar) {
    this();

    Preconditions.checkNotNull(allocator, "Memory allocator cannot be null");

    this.allocator = allocator;
    this.calendar = calendar;
    this.includeMetadata = false;
    this.reuseVectorSchemaRoot = false;
    this.targetBatchSize = DEFAULT_TARGET_BATCH_SIZE;
  }

  /**
   * Constructor for the <code>JavaAPIToArrowConfigBuilder</code>. Both the allocator and calendar are
   * required. A {@link NullPointerException} will be thrown if either of those arguments is <code>
   * null</code>.
   *
   * <p>The allocator is used to construct Arrow vectors from the JavaAPI ResultSet. The calendar is
   * used to determine the time zone of {@link java.sql.Timestamp} fields and convert {@link
   * java.sql.Date}, {@link java.sql.Time}, and {@link java.sql.Timestamp} fields to a single,
   * common time zone when reading from the result set.
   *
   * <p>The <code>includeMetadata</code> argument, if <code>true</code> will cause various
   * information about each database field to be added to the Vector Schema's field metadata.
   *
   * @param allocator The Arrow Vector memory allocator.
   * @param calendar The calendar to use when constructing timestamp fields.
   */
  public JavaAPIToArrowConfigBuilder(
      BufferAllocator allocator, Calendar calendar, boolean includeMetadata) {
    this(allocator, calendar);
    this.includeMetadata = includeMetadata;
  }

  /**
   * Sets the memory allocator to use when constructing the Arrow vectors from the ResultSet.
   *
   * @param allocator the allocator to set.
   * @exception NullPointerException if <code>allocator</code> is null.
   */
  public JavaAPIToArrowConfigBuilder setAllocator(BufferAllocator allocator) {
    Preconditions.checkNotNull(allocator, "Memory allocator cannot be null");
    this.allocator = allocator;
    return this;
  }

  /**
   * Sets the {@link Calendar} to use when constructing timestamp fields in the Arrow schema, and
   * reading time-based fields from the JavaAPI <code>ResultSet</code>.
   *
   * @param calendar the calendar to set.
   */
  public JavaAPIToArrowConfigBuilder setCalendar(Calendar calendar) {
    this.calendar = calendar;
    return this;
  }

  /**
   * Sets whether to include JavaAPI ResultSet field metadata in the Arrow Schema field metadata.
   *
   * @param includeMetadata Whether to include or exclude JavaAPI metadata in the Arrow Schema field
   *     metadata.
   * @return This instance of the <code>JavaAPIToArrowConfig</code>, for chaining.
   */
  public JavaAPIToArrowConfigBuilder setIncludeMetadata(boolean includeMetadata) {
    this.includeMetadata = includeMetadata;
    return this;
  }

  /**
   * Sets the mapping of column-index-to-{@link JavaAPIFieldInfo}. The column index is 1-based, to match the JavaAPI column index.
   *
   * @param map The mapping.
   * @return This instance of the <code>JavaAPIToArrowConfig</code>, for chaining.
   */
  public JavaAPIToArrowConfigBuilder setArraySubTypeByColumnIndexMap(Map<Integer, JavaAPIFieldInfo> map) {
    this.arraySubTypesByColumnIndex = map;
    return this;
  }

  /**
   * Sets the mapping of column-name-to-{@link JavaAPIFieldInfo}.
   *
   * @param map The mapping.
   * @return This instance of the <code>JavaAPIToArrowConfig</code>, for chaining.
   */
  public JavaAPIToArrowConfigBuilder setArraySubTypeByColumnNameMap(Map<String, JavaAPIFieldInfo> map) {
    this.arraySubTypesByColumnName = map;
    return this;
  }

  /**
   * Sets the mapping of column-index-to-{@link JavaAPIFieldInfo} used for column types.
   *
   * <p>This can be useful to override type information from JavaAPI drivers that provide incomplete
   * type info, e.g. DECIMAL with precision = scale = 0.
   *
   * <p>The column index is 1-based, to match the JavaAPI column index.
   *
   * @param map The mapping.
   */
  public JavaAPIToArrowConfigBuilder setExplicitTypesByColumnIndex(Map<Integer, JavaAPIFieldInfo> map) {
    this.explicitTypesByColumnIndex = map;
    return this;
  }

  /**
   * Sets the mapping of column-name-to-{@link JavaAPIFieldInfo} used for column types.
   *
   * <p>This can be useful to override type information from JavaAPI drivers that provide incomplete
   * type info, e.g. DECIMAL with precision = scale = 0.
   *
   * @param map The mapping.
   */
  public JavaAPIToArrowConfigBuilder setExplicitTypesByColumnName(Map<String, JavaAPIFieldInfo> map) {
    this.explicitTypesByColumnName = map;
    return this;
  }

  /**
   * Set the target number of rows to convert at once.
   *
   * <p>Use {@link JavaAPIToArrowConfig#NO_LIMIT_BATCH_SIZE} to read all rows at once.
   */
  public JavaAPIToArrowConfigBuilder setTargetBatchSize(int targetBatchSize) {
    this.targetBatchSize = targetBatchSize;
    return this;
  }

  /**
   * Set the function used to convert javaAPI types to Arrow types.
   *
   * <p>Defaults to wrapping {@link JavaAPIToArrowUtils#getArrowTypeFromJavaAPIType(JavaAPIFieldInfo,
   * Calendar)}.
   */
  public JavaAPIToArrowConfigBuilder setJavaAPIToArrowTypeConverter(
      Function<JavaAPIFieldInfo, ArrowType> javaAPIToArrowTypeConverter) {
    this.javaAPIToArrowTypeConverter = javaAPIToArrowTypeConverter;
    return this;
  }

  /**
   * Set the function used to get a JavaAPI consumer for a given type.
   *
   * <p>Defaults to wrapping {@link JavaAPIToArrowUtils#getConsumer(ArrowType, int, boolean,
   * FieldVector, JavaAPIToArrowConfig)}.
   */
  public JavaAPIToArrowConfigBuilder setJavaAPIConsumerGetter(
      JavaAPIToArrowConfig.JavaAPIConsumerFactory javaAPIConsumerGetter) {
    this.javaAPIConsumerGetter = javaAPIConsumerGetter;
    return this;
  }

  /**
   * Set whether to use the same {@link org.apache.arrow.vector.VectorSchemaRoot} instance on each
   * iteration, or to allocate a new one.
   */
  public JavaAPIToArrowConfigBuilder setReuseVectorSchemaRoot(boolean reuseVectorSchemaRoot) {
    this.reuseVectorSchemaRoot = reuseVectorSchemaRoot;
    return this;
  }

  /** Set metadata for schema. */
  public JavaAPIToArrowConfigBuilder setSchemaMetadata(Map<String, String> schemaMetadata) {
    this.schemaMetadata = schemaMetadata;
    return this;
  }

  /** Set metadata from columnIndex->meta map on per field basis. */
  public JavaAPIToArrowConfigBuilder setColumnMetadataByColumnIndex(
      Map<Integer, Map<String, String>> columnMetadataByColumnIndex) {
    this.columnMetadataByColumnIndex = columnMetadataByColumnIndex;
    return this;
  }

  /**
   * Set the rounding mode used when the scale of the actual value does not match the declared
   * scale.
   *
   * <p>By default, an error is raised in such cases.
   */
  public JavaAPIToArrowConfigBuilder setBigDecimalRoundingMode(RoundingMode bigDecimalRoundingMode) {
    this.bigDecimalRoundingMode = bigDecimalRoundingMode;
    return this;
  }

  /**
   * This builds the {@link JavaAPIToArrowConfig} from the provided {@link BufferAllocator} and {@link
   * Calendar}.
   *
   * @return The built {@link JavaAPIToArrowConfig}
   * @throws NullPointerException if either the allocator or calendar was not set.
   */
  public JavaAPIToArrowConfig build() {
    return new JavaAPIToArrowConfig(
        allocator,
        calendar,
        includeMetadata,
        reuseVectorSchemaRoot,
        arraySubTypesByColumnIndex,
        arraySubTypesByColumnName,
        targetBatchSize,
        javaAPIToArrowTypeConverter,
        javaAPIConsumerGetter,
        explicitTypesByColumnIndex,
        explicitTypesByColumnName,
        schemaMetadata,
        columnMetadataByColumnIndex,
        bigDecimalRoundingMode);
  }
}
