#!/usr/bin/python

import griddb_python as griddb
import sys, calendar

factory = griddb.StoreFactory.get_instance()

argv = sys.argv

#Get GridStore object
gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

#Get TimeSeries
#Reuse TimeSeries and data from sample 2
ts = gridstore.get_container("point01")

#Create normal query to get all row where active = FAlSE and voltage > 50
query = ts.query("select * from point01 where not active and voltage > 50")
rs = query.fetch()

#Get result
while rs.has_next():
	data = rs.next()
	timestamp = calendar.timegm(data[0].timetuple())
	gsTS = (griddb.TimestampUtils.get_time_millis(timestamp));

	#Perform aggregation query to get average value 
	#during 10 minutes later and 10 minutes earlier from this point
	aggCommand = "select AVG(voltage) from point01 where timestamp > TIMESTAMPADD(MINUTE, TO_TIMESTAMP_MS({0}), -10) AND timestamp < TIMESTAMPADD(MINUTE, TO_TIMESTAMP_MS({1}), 10)".format(gsTS, gsTS)
	aggQuery = ts.query(aggCommand) 
	aggRs = aggQuery.fetch()
	while aggRs.has_next():
		#Get aggregation result
		aggResult = aggRs.next()
		#Convert result to double and print out
		print("[Timestamp={0}] Average voltage = {1}".format(timestamp, aggResult.get(griddb.Type.DOUBLE )))
