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

    # Create Collection
    conInfo = griddb.ContainerInfo(name="SamplePython_PutRows",
                                   column_info_list=
                                   [["id", griddb.Type.INTEGER],
                                    ["productName", griddb.Type.STRING],
                                    ["count", griddb.Type.INTEGER]],
                                   type=griddb.ContainerType.COLLECTION,
                                   row_key=True)

    col = gridstore.put_container(conInfo)
    print("Create Collection name=SamplePython_PutRows")

    # Register multiple rows
    # (1)Get the container
    col1 = gridstore.get_container("SamplePython_PutRows")
    if col1 == None:
        print( "ERROR Container not found. name=SamplePython_PutRows")

    # (2) Register multiple rows
    rowList = []
    for i in range(0,5):
        rowList.append([i, "dvd", 10*i])
    col1.multi_put(rowList)
    print("Put Rows")
    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
