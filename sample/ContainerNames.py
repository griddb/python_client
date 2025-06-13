import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

try:

    #Get GridStore object
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])
    gridstore.get_container("containerName")
    print("Connect to Cluster")

    # Get a list of container names
    # (1)Get partition controller and number of partitions
    pc = gridstore.partition_info
    count = pc.partition_count
    # (2) Loop by the number of partitions to get a list of container names
    for i in range(0, count):
        list_container_names =  pc.get_container_names(i, 0)
        for j in range(0, len(list_container_names)):
            print(list_container_names[j])

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
