import jpype
import jpype.dbapi2
jpype.startJVM(classpath=["./gridstore.jar", "./gridstore-arrow.jar", "./gridstore-jdbc.jar"])
import griddb_python as griddb
import sys

### SQL create table/insert

url = "jdbc:gs://127.0.0.1:20001/myCluster/public"
conn = jpype.dbapi2.connect(url, driver="com.toshiba.mwcloud.gs.sql.Driver",
	driver_args={"user":"admin", "password":"admin"})

curs = conn.cursor()

curs.execute("DROP TABLE IF EXISTS Sample")
curs.execute("CREATE TABLE IF NOT EXISTS Sample ( id integer PRIMARY KEY, value string )")
print('SQL Create Table name=Sample')

curs.execute("INSERT INTO Sample values (0, 'test0'),(1, 'test1'),(2, 'test2'),(3, 'test3'),(4, 'test4')")
print('SQL Insert')

### NoSQL select

factory = griddb.StoreFactory.get_instance()

gridstore = factory.get_store(host="127.0.0.1", port=10001, cluster_name="myCluster", username="admin", password="admin")

col = gridstore.get_container("Sample")

q = col.query("select *")
rs = q.fetch()
while rs.has_next():
    row = rs.next()
    print(row)
