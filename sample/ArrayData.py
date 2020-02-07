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
    conInfo = griddb.ContainerInfo(name="SamplePython_ArrayData",
                                   column_info_list=
                                   [["id", griddb.Type.INTEGER],
                                    ["string_array", griddb.Type.STRING_ARRAY],
                                    ["integer_array", griddb.Type.INTEGER_ARRAY]],
                                   type=griddb.ContainerType.COLLECTION,
                                   row_key=True)

    col = gridstore.put_container(conInfo)
    print("Create Collection name=SamplePython_ArrayData")

    # Register array type data
    # (1)Array type data
    stringArray = ["Sales", "Development", "Marketing", "Research"]
    integerArray = [39, 92, 18, 51 ]
    # (2)Register a row
    col.put([0, stringArray, integerArray])
    print("Put Row (Array)")

    # Get array type data
    row = col.get(0)
    print("Get Row ", row)
    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
