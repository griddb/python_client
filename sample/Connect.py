import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
import sys
import os
factory = griddb.StoreFactory.get_instance()

argv = sys.argv

try:

    # (1)Get GridStore object
    # Multicast method
    gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

    # Fixed list method
    #gridstore = factory.get_store(notification_member=argv[1], cluster_name=argv[2], username=argv[3], password=argv[4])

    # Provider method
    #gridstore = factory.get_store(notification_provider=argv[1], cluster_name=argv[2], username=argv[3], password=argv[4])

    # (2)When operations such as container creation and acquisition are performed, it is connected to the cluster.
    gridstore.get_container("containerName")
    print("Connect to Cluster")
    print("success!")

except griddb.GSException as e:
    for i in range(e.get_error_stack_size()):
        print("[", i, "]")
        print(e.get_error_code(i))
        print(e.get_location(i))
        print(e.get_message(i))
