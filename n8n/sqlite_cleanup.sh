sqlite3 database.sqlite \
"DELETE FROM execution_data
 WHERE executionId IN (
   SELECT id FROM execution_entity
   WHERE finished = 1
     AND stoppedAt < datetime('now', '-1 days')
 );"
sqlite3 database.sqlite 'VACUUM;'
