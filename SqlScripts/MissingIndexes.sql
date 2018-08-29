-- This query checks and suggests to implement missing indexes. You should always check them manually before executing them.
SELECT 
	S.[name] AS schemaName, 
	O.[name] AS tableName, 
	ROW_NUMBER() OVER (PARTITION BY S.[name], O.[name]
						ORDER BY MIGS.avg_total_user_cost * MIGS.avg_user_impact * (MIGS.user_seeks + MIGS.user_scans) DESC
					) AS priorityRank,
	'CREATE INDEX ' + QUOTENAME('IX_' + O.[name] + '_'
	+ ISNULL(REPLACE(REPLACE(REPLACE(MID.equality_columns, '], [', '_'), ']', ''), '[', ''), '') 
	+ CASE WHEN equality_columns IS NOT NULL AND MID.inequality_columns IS NOT NULL THEN '_' ELSE '' END
	+ ISNULL(REPLACE(REPLACE(REPLACE(MID.inequality_columns, '], [', '_'), ']', ''), '[', ''), ''))
	+ ' ON ' + QUOTENAME(S.[name]) + '.' + QUOTENAME(O.[name]) 
	+ ' (' + ISNULL(equality_columns, '')
	+ CASE WHEN equality_columns IS NOT NULL AND MID.inequality_columns IS NOT NULL THEN ', ' ELSE '' END
	+ ISNULL(MID.inequality_columns, '') + ')' AS createIndexStatement,
	MID.equality_columns,
	MID.inequality_columns,
	O.object_id AS tableObjectId
FROM sys.DM_DB_MISSING_INDEX_GROUP_STATS MIGS
    INNER JOIN sys.DM_DB_MISSING_INDEX_GROUPS MIG ON MIG.index_group_handle = MIGS.group_handle
    INNER JOIN sys.DM_DB_MISSING_INDEX_DETAILS MID ON MID.index_handle = MIG.index_handle
    INNER JOIN sys.OBJECTS O ON O.object_id = MID.object_id  
    INNER JOIN sys.SCHEMAS S ON S.schema_id = O.schema_id
WHERE MIGS.avg_total_user_cost > 1 -- Check which level of expensive queries to count for index reduce
    AND MIGS.avg_user_impact > 90 -- Check over 90% of benefit without index
	AND MIGS.user_seeks + MIGS.user_scans > 1 -- Combained, because could use WHERE statement and sometimes not
    AND MID.database_id = DB_ID()

-- TODO check already inserted indexes they could make bottlenecks