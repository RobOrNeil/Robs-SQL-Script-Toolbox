/*******************
Author:		Rob Hendrix
Date:		2020-06-03
Script:		FindTextWithinObjects
Purpose:	Find objects in current or all databases with the text you are looking for.
*******************/

/** CONFIGURATION SETTINGS **/
DECLARE 
	 @TextToSearchFor		VARCHAR(50)	= 'Monkey'	-- What text are you looking for?
	,@WantProcedures		BIT			= 1			-- Do you want to look at stored procedures
	,@WantFunctions			BIT			= 1			-- Do you want to include functions
	,@WantViews				BIT			= 1			-- Do you want to include views
	,@WantCurrentDBOnly		BIT			= 0			-- Do you want to only look in the Current Database or All?

/************ DO NOT CHANGE BELOW THIS LINE ********************/
DECLARE 
	 @sql nvarchar(2000)
	,@dbcmd nvarchar(500)

SET @sql = '
SELECT
	 DB_NAME(DB_ID())			AS DatabaseName
	,SCHEMA_NAME(o.schema_id)	AS SchemaName
	,o.name						AS ObjectName
	,o.type						AS ObjectType
	,o.type_desc				AS ObjectTypeDescription
	,o.create_date				AS CreatedDate
	,o.modify_date				AS LastModifyDate
	,ec.Execution_count			AS Execution_count
	,REPLACE(REPLACE(m.definition, CHAR(10), CHAR(13) + CHAR(10)), CHAR(13) + CHAR(13) + CHAR(10), CHAR(13) + CHAR(10))				
								AS ObjectScript
FROM sys.objects AS o
	INNER JOIN sys.sql_modules AS m					ON o.object_id = m.object_id
	OUTER APPLY
		(
			SELECT 
				 DB_NAME(st.dbid) DBName
				,OBJECT_SCHEMA_NAME(st.objectid,dbid) SchemaName
				,OBJECT_NAME(st.objectid,dbid) StoredProcedure
				,max(cp.usecounts) Execution_count
			FROM sys.dm_exec_cached_plans cp
				CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
			WHERE DB_NAME(st.dbid) is not null
				AND st.objectid = o.object_id
				AND OBJECT_SCHEMA_NAME(st.objectid,dbid) = OBJECT_SCHEMA_NAME(o.object_id,dbid)
			GROUP BY cp.plan_handle, DB_NAME(st.dbid),
			OBJECT_SCHEMA_NAME(objectid,st.dbid), 
			OBJECT_NAME(objectid,st.dbid)
		) ec
WHERE o.is_ms_shipped = 0
	AND
		(
			('+ISNULL(CONVERT(char(1),@WantProcedures),0)+' = 0 OR o.type = ''P'')
			OR
			('+ISNULL(CONVERT(char(1),@WantFunctions),0)+' = 0 OR o.type IN (''FN'',''IF'',''AF''))
			OR
			('+ISNULL(CONVERT(char(1),@WantViews),0)+' = 0 OR o.type = ''V'')
		)
	AND m.definition LIKE ''%'+ISNULL(@TextToSearchFor,'')+'%'''

/**  GET ALL DATABASE OR CURRENT BASED ON VARIABLE **/
IF @WantCurrentDBOnly = 0
BEGIN
	SET @sql = 'USE [?] 

				IF DB_Name() IN (''master'',''model'',''msdb'',''Tempdb'') 
				BEGIN RETURN END 

				SELECT DB_NAME(DB_ID())'+@sql

	EXEC sp_MSforeachdb @sql
END
ELSE
BEGIN
	EXEC sp_executesql @sql
END;

GO
