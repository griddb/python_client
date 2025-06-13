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

import java.sql.Types;
import java.time.ZoneId;
import java.util.Calendar;
import java.util.TimeZone;

import org.apache.arrow.vector.BigIntVector;
import org.apache.arrow.vector.BitVector;
import org.apache.arrow.vector.DateDayVector;
import org.apache.arrow.vector.DateMilliVector;
import org.apache.arrow.vector.Decimal256Vector;
import org.apache.arrow.vector.DecimalVector;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.FixedSizeBinaryVector;
import org.apache.arrow.vector.Float4Vector;
import org.apache.arrow.vector.Float8Vector;
import org.apache.arrow.vector.IntVector;
import org.apache.arrow.vector.LargeVarBinaryVector;
import org.apache.arrow.vector.LargeVarCharVector;
import org.apache.arrow.vector.SmallIntVector;
import org.apache.arrow.vector.TimeMicroVector;
import org.apache.arrow.vector.TimeMilliVector;
import org.apache.arrow.vector.TimeNanoVector;
import org.apache.arrow.vector.TimeSecVector;
import org.apache.arrow.vector.TimeStampVector;
import org.apache.arrow.vector.TinyIntVector;
import org.apache.arrow.vector.VarBinaryVector;
import org.apache.arrow.vector.VarCharVector;
import org.apache.arrow.vector.complex.ListVector;
import org.apache.arrow.vector.complex.MapVector;
import org.apache.arrow.vector.types.pojo.ArrowType;

import com.toshiba.mwcloud.gs.GSType;

/**
 * Visitor to create the base ColumnBinder for a vector.
 *
 * <p>To handle null values, wrap the returned binder in a {@link NullableColumnBinder}.
 */
public class ColumnBinderArrowTypeVisitor implements ArrowType.ArrowTypeVisitor<ColumnBinder> {
  private final FieldVector vector;
  private final GSType gsType;

  /**
   * Create a binder using a custom GS type code.
   *
   * @param vector The vector that the binder will wrap.
   * @param gsType The GS type code (or null to use the default).
   */
  public ColumnBinderArrowTypeVisitor(FieldVector vector, GSType gsType) {
    this.vector = vector;
    this.gsType = gsType;
  }

  @Override
  public ColumnBinder visit(ArrowType.Null type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Struct type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.List type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.LargeList type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.FixedSizeList type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Union type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Map type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Int type) {
    if (!type.getIsSigned()) {
      throw new UnsupportedOperationException(
          "No column binder implemented for unsigned type " + type);
    }
    switch (type.getBitWidth()) {
      case 8:
        return gsType == null
            ? new TinyIntBinder((TinyIntVector) vector)
            : new TinyIntBinder((TinyIntVector) vector, gsType);
      case 16:
        return gsType == null
            ? new SmallIntBinder((SmallIntVector) vector)
            : new SmallIntBinder((SmallIntVector) vector, gsType);
      case 32:
        return gsType == null
            ? new IntBinder((IntVector) vector)
            : new IntBinder((IntVector) vector, gsType);
      case 64:
        return gsType == null
            ? new BigIntBinder((BigIntVector) vector)
            : new BigIntBinder((BigIntVector) vector, gsType);
      default:
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
    }
  }

  @Override
  public ColumnBinder visit(ArrowType.FloatingPoint type) {
    switch (type.getPrecision()) {
      case SINGLE:
        return gsType == null
            ? new Float4Binder((Float4Vector) vector)
            : new Float4Binder((Float4Vector) vector, gsType);
      case DOUBLE:
        return gsType == null
            ? new Float8Binder((Float8Vector) vector)
            : new Float8Binder((Float8Vector) vector, gsType);
      default:
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
    }
  }

  @Override
  public ColumnBinder visit(ArrowType.Utf8 type) {
    VarCharVector varChar = (VarCharVector) vector;
    return gsType == null
        ? new VarCharBinder<>(varChar, GSType.STRING)
        : new VarCharBinder<>(varChar, gsType);
  }

  @Override
  public ColumnBinder visit(ArrowType.Utf8View type) {
    throw new UnsupportedOperationException(
        "Column binder implemented for type " + type + " is not supported");
  }

  @Override
  public ColumnBinder visit(ArrowType.LargeUtf8 type) {
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Binary type) {
    VarBinaryVector varBinary = (VarBinaryVector) vector;
    return gsType == null
        ? new VarBinaryBinder<>(varBinary, GSType.BLOB)
        : new VarBinaryBinder<>(varBinary, gsType);
  }
  
  @Override
  public ColumnBinder visit(ArrowType.BinaryView type) {
    throw new UnsupportedOperationException(
        "Column binder implemented for type " + type + " is not supported");
  }
  
  @Override
  public ColumnBinder visit(ArrowType.LargeBinary type) {
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.FixedSizeBinary type) {
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Bool type) {
    return gsType == null
        ? new BitBinder((BitVector) vector)
        : new BitBinder((BitVector) vector, gsType);
  }

  @Override
  public ColumnBinder visit(ArrowType.Decimal type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Date type) {
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Time type) {
        throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Timestamp type) {
    Calendar calendar = null;
    final String timezone = type.getTimezone();
    if (timezone != null && !timezone.isEmpty()) {
      calendar = Calendar.getInstance(TimeZone.getTimeZone(ZoneId.of(timezone)));
    }
    return new TimeStampBinder((TimeStampVector) vector, calendar);
  }

  @Override
  public ColumnBinder visit(ArrowType.Interval type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }

  @Override
  public ColumnBinder visit(ArrowType.Duration type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }
  
  @Override
  public ColumnBinder visit(ArrowType.ListView type) {
    throw new UnsupportedOperationException("No column binder implemented for type " + type);
  }
}
