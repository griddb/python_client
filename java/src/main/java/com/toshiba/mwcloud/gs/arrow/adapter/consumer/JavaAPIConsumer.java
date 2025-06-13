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

package com.toshiba.mwcloud.gs.arrow.adapter.consumer;

import java.io.IOException;

import org.apache.arrow.vector.ValueVector;

import com.toshiba.mwcloud.gs.GSException;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.RowSet;

/**
 * An abstraction that is used to consume values from {@link RowSet}.
 * @param <T> The vector within consumer or its delegate, used for partially consume purpose.
 */
public interface JavaAPIConsumer<T extends ValueVector> extends AutoCloseable {

  /**
   * Consume a specific type value from {@link RowSet} and write it to vector.
   */
  void consume(Row row) throws GSException, IOException;

  /**
   * Close this consumer, do some clean work such as clear reuse ArrowBuf.
   */
  void close() throws Exception;

  /**
   * Reset the vector within consumer for partial read purpose.
   */
  void resetValueVector(T vector);
}
