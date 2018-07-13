#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

NumContainer = 100
NumRow = 100

try:
	store = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

	for i in range(NumContainer):
		conInfo = griddb.ContainerInfo("container" + str(i),
					[["name", griddb.Type.STRING],
		            ["status", griddb.Type.BOOL],
		            ["count", griddb.Type.LONG]],
		            griddb.ContainerType.COLLECTION, True)
		col = store.put_container(conInfo)

	print("[MultiPut S]")
	
	containerEntry = {}
	collectionListRows = []
	for i in range(NumContainer):
		for j in range(NumRow):
			collectionListRows.append(["name" + str(j), True, j])
		containerEntry.update({"container" + str(i): collectionListRows})
	store.multi_put(containerEntry)

	print("[MultiPut E]")

except griddb.GSException as e:
	for i in range(e.get_error_stack_size()):
		print("[", i, "]")
		print(e.get_error_code(i))
		print(e.get_message(i))
