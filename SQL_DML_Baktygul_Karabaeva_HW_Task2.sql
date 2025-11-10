-- DELETE and TRUNCATE operations task

-- =================================================================================

-- SUBTASK 1: Create table ‘table_to_delete’ and fill it with the following query:
-- =================================================================================

CREATE TABLE public.table_to_delete AS 
SELECT 'veeeeeeery_long_string' || x AS col 
FROM generate_series(1,(10^7)::int) x;



-- SUBTASK 2: Lookup how much space this table consumes with the following query:
-- ==============================================================================

SELECT *, 
       pg_size_pretty(total_bytes) AS total, 
       pg_size_pretty(index_bytes) AS INDEX, 
       pg_size_pretty(toast_bytes) AS toast, 
       pg_size_pretty(table_bytes) AS TABLE 
FROM (
    SELECT *, 
           total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes 
    FROM (
        SELECT c.oid,
               nspname AS table_schema, 
               relname AS TABLE_NAME, 
               c.reltuples AS row_estimate, 
               pg_total_relation_size(c.oid) AS total_bytes, 
               pg_indexes_size(c.oid) AS index_bytes, 
               pg_total_relation_size(reltoastrelid) AS toast_bytes 
        FROM pg_class c 
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace 
        WHERE relkind = 'r'
    ) a
) a 
WHERE table_name LIKE '%table_to_delete%';


-- SUBTASK 3: Issue the following DELETE operation on ‘table_to_delete’:
-- =====================================================================

DELETE FROM public.table_to_delete 
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;

--a) Note how much time it takes to perform this DELETE statement; 
-- Answer: 9.2s

-- b) Lookup how much space this table consumes after previous DELETE;
-- Answer: 575 MB

/* c) Perform the following command (if you're using DBeaver, 
 * press Ctrl+Shift+O to observe server output (VACUUM results)): 
 * VACUUM FULL VERBOSE table_to_delete;*/ 
 
 VACUUM FULL VERBOSE table_to_delete;
 
 -- d) Check space consumption of the table once again and make conclusions;
 -- Answer: 383 MB
 
 -- e) Recreate ‘table_to_delete’ table;
 
DROP TABLE table_to_delete;

-- e) Lookup how much space this table consumes now:
-- Answer: 575 MB


-- SUBTASK 4: Issue the following TRUNCATE operation: 
-- ==================================================

TRUNCATE table_to_delete;
-- a) Note how much time it takes to perform this TRUNCATE statement.
-- Answer: 0.0s

-- b) Compare with previous results and make conclusion.
-- Answer: DELETE took 9.2s, while TRUNCATE operated in 0.0s

-- c) Check space consumption of the table once again and make conclusions.
-- Answer: After DELETE 575 MB, after VACUUM 383 MB, after TRUNCATE 8192 bytes


-- SUBTASK 5: Hand over your investigation's results to your trainer.
-- ==================================================================

-- a) Space consumption of ‘table_to_delete’ table before and after each operation;
-- Answer: 
--Initial Creation: total size - 575 MB, table size - 575 MB, ~10M rows
-- After DELETE (1/3 rows): total size - 575 MB, table size - 575 MB, ~6M rows
-- After VACUUM FULL: total size - 383 MB, table size - 383 MB, ~6M rows
-- After Table Recreate: total size - 575 MB, table size - 575 MB
-- After TRUNCATE: total size - 8192 bytes, table size - 0 bytes

-- b) Duration of each operation (DELETE, TRUNCATE):
-- Answer: DELETE took 9.2s, while TRUNCATE operated in 0.0s

