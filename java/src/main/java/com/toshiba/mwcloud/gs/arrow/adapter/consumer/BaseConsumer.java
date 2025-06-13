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

import org.apache.arrow.vector.ValueVector;

/**
 * Base class for all consumers.
 *
 * @param <V> vector type.
 */
public abstract class BaseConsumer<V extends ValueVector> implements JavaAPIConsumer<V> {

  protected V vector;

  protected final int columnIndexInRowSet;

  protected int currentIndex;

  /**
   * Constructs a new consumer.
   *
   * @param vector the underlying vector for the consumer.
   * @param index the column id for the consumer.
   */
  public BaseConsumer(V vector, int index) {
    this.vector = vector;
    this.columnIndexInRowSet = index;
  }

  @Override
  public void close() throws Exception {
    this.vector.close();
  }

  @Override
  public void resetValueVector(V vector) {
    this.vector = vector;
    this.currentIndex = 0;
  }
}
