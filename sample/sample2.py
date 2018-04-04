#!/usr/bin/python

import griddb_python as griddb
import sys
import datetime

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

#Get GridStore object
gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

#Create TimeSeries
conInfo = griddb.ContainerInfo("point01",
				[["timestamp", griddb.GS_TYPE_TIMESTAMP],
	            ["active", griddb.GS_TYPE_BOOL],
	            ["voltage", griddb.GS_TYPE_DOUBLE]],
			griddb.GS_CONTAINER_TIME_SERIES, True)
ts = gridstore.put_container(conInfo)

#Put row to timeseries with current timestamp
now = datetime.datetime.utcnow()
ts.put([now, False, 100])

#Create normal query for range of timestamp from 6 hours ago to now
query = ts.query("select * where timestamp > TIMESTAMPADD(HOUR, NOW(), -6)")
rs = query.fetch()

#Get result
while rs.has_next():
	data = rs.next()
	timestamp = str(data[0])
	active = data[1]
	voltage = data[2]
	print("Time={0} Active={1} Voltage={2}".format(timestamp, active, voltage))

