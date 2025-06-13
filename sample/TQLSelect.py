import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
import sys

containerName = "SamplePython_TQLSelect"
rowCount = 5
nameList = ["notebook PC", "desktop PC", "keyboard", "mouse", "printer"]
numberList = [108, 72, 25, 45, 62 ]
queryStr = "SELECT * WHERE count >= 50 ORDER BY id"

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

try:

    # Get GridStore object
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

    # When operations such as container creation and acquisition are performed, it is connected to the cluster.
    gridstore.get_container("containerName")
    print("Connect to Cluster")

    conInfo = griddb.ContainerInfo(name=containerName,
                                   column_info_list=
                                   [["id", griddb.Type.INTEGER],
                                    ["productName", griddb.Type.STRING],
                                    ["count", griddb.Type.INTEGER]],
                                   type=griddb.ContainerType.COLLECTION,
                                   row_key=True)

    col = gridstore.put_container(conInfo)
    print("Create Collection name=", containerName)

    # Register multiple rows
    rowList = []
    for i in range(0, rowCount):
        rowList.append([i, nameList[i], numberList[i]])
    col.multi_put(rowList)
    print("Sample data generation: Put Rows count=", rowCount)

    # Search by TQL
    # (1)Get the container
    col1 = gridstore.get_container(containerName)
    if col1 == None:
        print( "ERROR Container not found. name=", containerName)

    # (2)Execute search with TQL
    print("TQL query : ", queryStr)
    query = col1.query(queryStr)
    rs = query.fetch()

    # (3)Get results
    while rs.has_next():
    # (4) Get row
        row = rs.next()
        print("TQL result: id=", row[0], ", productName=", row[1], ", count=", row[2])
    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
