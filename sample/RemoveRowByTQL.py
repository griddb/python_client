import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

containerName = "SamplePython_RemoveRowByTQL"
rowCount = 5
nameList = ["notebook PC", "desktop PC", "keyboard", "mouse", "printer"]
numberList = [108, 72, 25, 45, 62 ]
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
    print("Sample data generation: Create Collection name=", containerName)

    # Register multiple rows
    rowList = []
    for i in range(0,rowCount):
        rowList.append([i, nameList[i], numberList[i]])
    col.multi_put(rowList)
    print("Sample data generation: Put Rows count=", rowCount)

    # Delete a row
    # (1)Get the container
    col1 = gridstore.get_container(containerName)
    if col1 == None:
        print( "ERROR Container not found. name=", containerName)

    # (2)Change auto commit mode to false
    col1.set_auto_commit(False)

    # (3)Execute search with TQL
    print("Delete query : SELECT * WHERE count < 50")
    query = col1.query("SELECT * WHERE count < 50")
    rs = query.fetch(True)

    # (4)Delete a row that was found in the search
    while rs.has_next():
        row = rs.next()
        rs.remove()

    # (5)Commit
    col1.commit()
    print("Delete Row")
    print("success!")

except griddb.GSException as e:
  for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
