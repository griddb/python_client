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
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.GSException;

import com.toshiba.mwcloud.gs.arrow.adapter.JavaAPIFieldInfo;
import com.toshiba.mwcloud.gs.arrow.adapter.consumer.exceptions.JavaAPIConsumerException;

import org.apache.arrow.util.AutoCloseables;
import org.apache.arrow.vector.ValueVector;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.types.pojo.ArrowType;

/**
 * Composite consumer which hold all consumers.
 * It manages the consume and cleanup process.
 */
public class CompositeJavaAPIConsumer implements JavaAPIConsumer {

  private final JavaAPIConsumer[] consumers;

  /**
   * Construct an instance.
   */
  public CompositeJavaAPIConsumer(JavaAPIConsumer[] consumers) {
    this.consumers = consumers;
  }

  @Override
  public void consume(Row row) throws GSException, IOException {
    for (int i = 0; i < consumers.length; i++) {
      try {
        consumers[i].consume(row);
      } catch (Exception e) {
      	throw e;
      }
    }
  }

  @Override
  public void close() {

    try {
      // clean up
      AutoCloseables.close(consumers);
    } catch (Exception e) {
      throw new RuntimeException("Error occurred while releasing resources.", e);
    }

  }

  @Override
  public void resetValueVector(ValueVector vector) {

  }

  /**
   * Reset inner consumers through vectors in the vector schema root.
   */
  public void resetVectorSchemaRoot(VectorSchemaRoot root) {
    assert root.getFieldVectors().size() == consumers.length;
    for (int i = 0; i < consumers.length; i++) {
      consumers[i].resetValueVector(root.getVector(i));
    }
  }
}

