import jpype
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar"])
import griddb_python as griddb
import sys
import pyarrow as pa
import pandas as pd

argv = sys.argv

ra = griddb.RootAllocator(sys.maxsize)

df1 = pd.read_csv("data.csv")

factory = griddb.StoreFactory.get_instance()

gridstore = factory.get_store(host=argv[1], port=int(argv[2]), cluster_name=argv[3], username=argv[4], password=argv[5])

colInfoL = []
colInfoL.append(["id", griddb.Type.LONG])
colInfoL.append(["c1", griddb.Type.STRING])
colInfoL.append(["c2", griddb.Type.BOOL])
	
conInfo = griddb.ContainerInfo("p01", colInfoL,
		            griddb.ContainerType.COLLECTION, True)
gridstore.drop_container("p01")
col = gridstore.put_container(conInfo)

rb = pa.record_batch(df1)
col.multi_put(rb, ra)

q = col.query("select *")
q.set_fetch_options(root_allocator=ra)
rs = q.fetch()
rb = rs.next_record_batch()
df2 = rb.to_pandas()

