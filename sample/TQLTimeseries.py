#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

containerName = "SamplePython_TQLTimeseries"
rowCount = 4
dateList = ["2018-12-01T10:00:00.000Z", "2018-12-01T10:10:00.000Z", "2018-12-01T10:20:00.000Z", "2018-12-01T10:40:00.000Z" ]
value1List = [1, 3, 2, 4 ]
value2List = [10.3, 5.7, 8.2, 4.5 ]

try:

    # Get GridStore object
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

    # When operations such as container creation and acquisition are performed, it is connected to the cluster.
    gridstore.get_container("containerName")
    print("Connect to Cluster")

    conInfo = griddb.ContainerInfo(name=containerName,
                                   column_info_list=
                                   [["date", griddb.Type.TIMESTAMP],
                                    ["value1", griddb.Type.INTEGER],
                                    ["value2", griddb.Type.DOUBLE]],
                                   type=griddb.ContainerType.TIME_SERIES)

    col = gridstore.put_container(conInfo)
    print("Sample data generation: Create Collection name=", containerName)
    print("Sample data generation:  column=(", conInfo.column_info_list[0][0], ",", conInfo.column_info_list[1][0], ",", conInfo.column_info_list[2][0], ")")

    for i in range(0, rowCount):
        print("Sample data generation:  row=(", dateList[i], ", ", value1List[i], ",",  "%f" %(value2List[i]),")")
    # Register multiple rows
    rowList = []

    for i in range(0, rowCount):
        rowList.append([dateList[i], value1List[i], value2List[i]])
    col.multi_put(rowList)
    print("Sample data generation: Put Rows count=", rowCount)

    # Aggregation operations specific to time series
    # Get the container
    col1 = gridstore.get_container(containerName)
    if col1 == None:
        print( "ERROR Container not found. name=", containerName)

    # weighted average TIME_AVG
    # (1)Execute aggregation operation in TQL
    print("TQL query : ", "SELECT TIME_AVG(value1)")
    query = col1.query("SELECT TIME_AVG(value1)")
    rs = query.fetch()
    # (2)Get the result
    while rs.has_next():
    # (3)Get the result of the aggregation operation
        aggregationResult = rs.next()
        value = aggregationResult.get(griddb.Type.DOUBLE)
        print("TQL result:", "%f" %(value))

    # Time series specific selection operation
    # TIME_NEXT
    # (1)Execute aggregation operation in TQL
    print("TQL query : ", "SELECT TIME_NEXT(*, TIMESTAMP('2018-12-01T10:10:00.000Z'))")
    query1 = col1.query("SELECT TIME_NEXT(*, TIMESTAMP('2018-12-01T10:10:00.000Z'))")
    rs1 = query1.fetch()
    # (2)Get the result
    while rs1.has_next():
        row1 = rs1.next()
        print("TQL result: row=(", row1[0], ",", row1[1], ",", "%f" %(row1[2]), ")")

    # Time series specific interpolation operation
    # TIME_INTERPOLATED
    # (1)Execute aggregation operation in TQL
    print("TQL query : ", "SELECT TIME_INTERPOLATED(value1, TIMESTAMP('2018-12-01T10:30:00.000Z'))")
    query2 = col1.query("SELECT TIME_INTERPOLATED(value1, TIMESTAMP('2018-12-01T10:30:00.000Z'))")
    rs2 = query2.fetch()
    # (2)Get the result
    while rs2.has_next():
        row2 = rs2.next()
        print("TQL result: row=(", row2[0], ",", row2[1], ",", "%f" %(row2[2]), ")")

    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
