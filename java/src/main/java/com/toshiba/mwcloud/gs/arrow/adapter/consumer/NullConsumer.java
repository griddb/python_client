/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.toshiba.mwcloud.gs.arrow.adapter.consumer;

import org.apache.arrow.vector.NullVector;
import com.toshiba.mwcloud.gs.Row;
import com.toshiba.mwcloud.gs.GSException;

/**
 * Consumer which consume null type values from RowSet. Corresponding to {@link
 * org.apache.arrow.vector.NullVector}.
 */
public class NullConsumer extends BaseConsumer<NullVector> {

  public NullConsumer(NullVector vector) {
    super(vector, 0);
  }

  @Override
  public void consume(Row row) throws GSException {}
}
