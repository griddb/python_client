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

package com.toshiba.mwcloud.gs.arrow.adapter.consumer.exceptions;

import com.toshiba.mwcloud.gs.arrow.adapter.JavaAPIFieldInfo;

import org.apache.arrow.vector.types.pojo.ArrowType;

/**
 * Exception while consuming JavaAPI data. This exception stores the JavaAPIFieldInfo for the column and the
 * ArrowType for the corresponding vector for easier debugging.
 */
public class JavaAPIConsumerException extends RuntimeException {
  final JavaAPIFieldInfo fieldInfo;
  final ArrowType arrowType;

  /**
   * Construct JavaAPIConsumerException with all fields.
   *
   * @param message   error message
   * @param cause     original exception
   * @param fieldInfo JavaAPIFieldInfo for the column
   * @param arrowType ArrowType for the corresponding vector
   */
  public JavaAPIConsumerException(String message, Throwable cause, JavaAPIFieldInfo fieldInfo, ArrowType arrowType) {
    super(message, cause);
    this.fieldInfo = fieldInfo;
    this.arrowType = arrowType;
  }

  public ArrowType getArrowType() {
    return this.arrowType;
  }

  public JavaAPIFieldInfo getFieldInfo() {
    return this.fieldInfo;
  }
}
