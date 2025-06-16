import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
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
    conInfo = griddb.ContainerInfo(name="SamplePython_Info",
                                   column_info_list=
                                   [["id", griddb.Type.INTEGER],
                                    ["productName", griddb.Type.STRING],
                                    ["count", griddb.Type.INTEGER]],
                                   type=griddb.ContainerType.COLLECTION,
                                   row_key=True)

    col = gridstore.put_container(conInfo)
    print("Sample data generation: Create Collection name=SamplePython_Info")

    # Get container information
    # (1)Get container information
    containerInfor = gridstore.get_container_info("SamplePython_Info")

    # (2)Display container information
    print("Get ContainerInfo:\n    name =", containerInfor.name)

    if (containerInfor.type == griddb.ContainerType.COLLECTION):
        print("    type=Collection")
    else:
        print("    type=Timeseries")

    print("    rowKeyAssigned=", containerInfor.row_key)

    count = len(containerInfor.column_info_list)
    print("    columnCount=", count)

    for i in range(0, count):
        print("    column (", containerInfor.column_info_list[i][0],",", containerInfor.column_info_list[i][1],")")
    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
