#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv
containerName = "SamplePython_Index"

try:

    # Get GridStore object
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

    # When operations such as container creation and acquisition are performed, it is connected to the cluster.
    gridstore.get_container("containerName")
    print("Connect to Cluster")

    # Create Collection
    conInfo = griddb.ContainerInfo(name=containerName,
                                   column_info_list=
                                   [["id", griddb.Type.INTEGER],
                                    ["productName", griddb.Type.STRING],
                                    ["count", griddb.Type.INTEGER]],
                                   type=griddb.ContainerType.COLLECTION,
                                   row_key=True)
    gridstore.drop_container(containerName)
    col = gridstore.put_container(conInfo)
    print("Create Collection name=",containerName)

    # Get the container
    col1 = gridstore.get_container(containerName)
    if col1 == None:
        print( "ERROR Container not found. name=",containerName)

    # Create an index
    col1.create_index(column_name="count", index_type=griddb.IndexType.HASH, name="hash_index")
    print("Create Index")

    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
