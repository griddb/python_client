#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

NumContainer = 10

try:
	store = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

	print("[MultiGet S]")

	listCon = []
	listQuery = []
	for i in range(NumContainer):
		container = store.get_container("container" + str(i))
		if container == None:
			print("container: None")
		listCon.append(container)
		query = container.query("select * where count=10")
		if query == None:
			print("query: None")
		listQuery.append(query)
	store.fetch_all(listQuery)
	for q in listQuery:
		rs = q.get_row_set()
		while rs.has_next():
			row = rs.next()
			print(row)

	print("[MultiGet E]")

except griddb.GSException as e:
	for i in range(e.get_error_stack_size()):
		print("[", i, "]")
		print(e.get_error_code(i))
		print(e.get_message(i))
