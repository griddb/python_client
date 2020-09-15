#!/usr/bin/python

import griddb_python as griddb
import sys
import pandas

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

blob = bytearray([65, 66, 67, 68, 69, 70, 71, 72, 73, 74])
update = False
containerName = "SamplePython_PutRows"

try:
    # Get GridStore object
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

    # Create Collection
    conInfo = griddb.ContainerInfo(containerName,
                    [["name", griddb.Type.STRING],
                    ["status", griddb.Type.BOOL],
                    ["count", griddb.Type.LONG],
                    ["lob", griddb.Type.BLOB]],
                    griddb.ContainerType.COLLECTION, True)
    col = gridstore.put_container(conInfo)
    print("Create Collection name=", containerName)

    # Put rows
    rows = pandas.DataFrame([["name01", False, 1, blob], ["name02", False, 1, blob]])
    col.put_rows(rows)
    print("Put rows with DataFrame")
    print("Success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
