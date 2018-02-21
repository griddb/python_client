#!/usr/bin/python

import griddb_python as griddb
import sys

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

blob = bytearray([65, 66, 67, 68, 69, 70, 71, 72, 73, 74])
update = True

try:
	#Get GridStore object
	gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

	#Create Collection
	conInfo = griddb.ContainerInfo("col01",
					[["name", griddb.GS_TYPE_STRING],
		            ["status", griddb.GS_TYPE_BOOL],
		            ["count", griddb.GS_TYPE_LONG],	
		            ["lob", griddb.GS_TYPE_BLOB]],
		            griddb.GS_CONTAINER_COLLECTION, True)
	col = gridstore.put_container(conInfo)

	#Change auto commit mode to false
	col.set_auto_commit(False)

	#Set an index on the Row-key Column
	col.create_index("name", griddb.GS_INDEX_FLAG_DEFAULT)

	#Set an index on the Column
	col.create_index("count", griddb.GS_INDEX_FLAG_DEFAULT)

	#Put row: RowKey is "name01"
	ret = col.put(["name01", False, 1, blob])
	#Remove row with RowKey "name01"
	col.remove("name01")

	#Put row: RowKey is "name02"
	col.put(["name02", False, 1, blob])
	col.commit();

	mlist = col.get("name02")
	#print(mlist)

	#Create normal query
	query=col.query("select * where name = 'name02'")

	#Execute query
	rs = query.fetch(update)
	while rs.has_next():
		data = rs.next()

		data[2] = data[2] + 1
		print("Person: name={0} status={1} count={2} lob=[{3}]".format(data[0], data[1], data[2], ', '.join(str(e) for e in data[3])))

		#Update row
		rs.update(data)

	#End transaction
	col.commit()

except griddb.GSException as e:
	for i in range(e.get_error_stack_size()):
		print("[", i, "]")
		print(e.get_error_code(i))
		print(e.get_location(i))
		print(e.get_message(i))
