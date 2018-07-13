#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

NumContainer = 10
NumRow = 2

try:
	gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

	print("[MultiGet S]")

	predEntry = {}
	for i in range(NumContainer):
		keys = []
		pred = gridstore.create_row_key_predicate(griddb.Type.STRING)
		for j in range(NumRow):
			keys.append("name" + str(j))
		pred.set_distinct_keys(keys)
		predEntry.update({"container" + str(i): pred})
	resultDict = gridstore.multi_get(predEntry)
	for containerName, rows in resultDict.items():
		print(containerName, rows)

	print("[MultiGet E]")

except griddb.GSException as e:
	for i in range(e.get_error_stack_size()):
		print("[", i, "]")
		print(e.get_error_code(i))
		print(e.get_message(i))
