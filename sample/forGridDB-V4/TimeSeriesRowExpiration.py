#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

try:

    # Get GridStore object
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

    # When operations such as container creation and acquisition are performed, it is connected to the cluster.
    gridstore.get_container("containerName")
    print("Connect to Cluster")

    # Set row expiration release
    timeProp = griddb.ExpirationInfo(100, griddb.GS_TIME_UNIT_DAY, 5)
    # Create a time series container
    conInfo = griddb.ContainerInfo(name="SamplePython_RowExpiration",
                                   column_info_list=
                                   [["date", griddb.Type.TIMESTAMP],
                                    ["value", griddb.Type.DOUBLE]],
                                   type=griddb.ContainerType.TIME_SERIES,
                                   expiration=timeProp)

    ts = gridstore.put_container(conInfo)
    print("Create TimeSeries & Set Row Expiration name=SamplePython_RowExpiration")
    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
