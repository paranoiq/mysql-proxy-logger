-- package.path = package.path .. ';C:\\bin'
require("ansicolors")

local schar = string.char

function s(n)
  if n == 0 or n > 1 then
    return 's'
  else
    return ''
  end
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function connect_server()
  -- log_other('CONNECT', '')
end

function read_auth()
  vid = tostring(proxy.connection.server.mysqld_version)
  version = vid:sub(1, 1) .. '.' .. vid:sub(3, 3) .. '.' .. vid:sub(4)
  log_other('CONNECT', version .. ', ' .. proxy.connection.client.username .. ', ' .. proxy.connection.client.default_db)
end

function read_query(packet)
  type = packet:byte()
  data = ''
  if type == proxy.COM_SLEEP then
    message = 'SLEEP'
  elseif type == proxy.COM_QUIT then
    message = 'QUIT'
  elseif type == proxy.COM_INIT_DB then
    message = 'INIT DB'
    data = packet:sub(2)
  elseif type == proxy.COM_QUERY then
    message = 'QUERY'
    query = trim(packet:sub(2):gsub("[\n][ \t]+", "\n  "))
    log_query(message, query)
    if query:sub(0, 6) == 'SELECT' then
      id = 1
    elseif query:sub(0, 6) == 'INSERT' or query:sub(0, 7) == 'REPLACE' then
      id = 2
    elseif query:sub(0, 6) == 'UPDATE' or query:sub(0, 6) == 'DELETE' then
      id = 3
    else
      id = 0
    end
    proxy.queries:append(id, packet, {resultset_is_needed = true})
    return proxy.PROXY_SEND_QUERY
  elseif type == proxy.COM_FIELD_LIST then
    message = 'FIELD LIST'
  elseif type == proxy.COM_CREATE_DB then
    message = 'CREATE DB'
    data = packet:sub(2)
  elseif type == proxy.COM_DROP_DB then
    message = 'DROP DB'
    data = packet:sub(2)
  elseif type == proxy.COM_REFRESH then
    message = 'REFRESH'
  elseif type == proxy.COM_SHUTDOWN then
    message = 'SHUTDOWN'
  elseif type == proxy.COM_STATISTICS then
    message = 'STATISTICS'
  elseif type == proxy.COM_PROCESS_INFO then
    message = 'PROCESS INFO'
  elseif type == proxy.COM_CONNECT then
    message = 'CONNECT'
  elseif type == proxy.COM_PROCESS_KILL then
    message = 'PROCESS KILL'
  elseif type == proxy.COM_DEBUG then
    message = 'DEBUG'
  elseif type == proxy.COM_PING then
    message = 'PING'
  elseif type == proxy.COM_TIME then
    message = 'TIME'
  elseif type == proxy.COM_DELAYED_INSERT then
    message = 'DELAYED INSERT'
  elseif type == proxy.COM_CHANGE_USER then
    message = 'CHANGE USER'
    data = packet:sub(2)
  elseif type == proxy.COM_BINLOG_DUMP then
    message = 'BINLOG DUMP'
  elseif type == proxy.COM_TABLE_DUMP then
    message = 'TABLE DUMP'
  elseif type == proxy.COM_CONNECT_OUT then
    message = 'CONNECT OUT'
  elseif type == proxy.COM_REGISTER_SLAVE then
    message = 'REGISTER SLAVE'
  elseif type == proxy.COM_STMT_PREPARE then
    message = 'STMT PREPARE'
    query = trim(packet:sub(2):gsub("[\n][ \t]+", "\n  "))
    log_query(message, query)
  elseif type == proxy.COM_STMT_EXECUTE then
    message = 'STMT EXECUTE'
  elseif type == proxy.COM_STMT_SEND_LONG_DATA then
    message = 'STMT SEND LONG DATA'
  elseif type == proxy.COM_STMT_CLOSE then
    message = 'STMT CLOSE'
  elseif type == proxy.COM_STMT_RESET then
    message = 'STMT RESET'
  elseif type == proxy.COM_SET_OPTION then
    message = 'SET OPTION'
  elseif type == proxy.COM_STMT_FETCH then
    message = 'STMT FETCH'
  elseif type == proxy.COM_RESET_CONNECTION then
    message = 'RESET CONNECTION'
  elseif type == proxy.COM_DAEMON then
    message = 'DAEMON'
  elseif type == proxy.COM_ERROR then
    message = 'ERROR'
  else
    message = 'UNKNOWN'
  end
  err = pcall(log_other(message, data))
  if err then
    print(err.code)
  end
end

function read_query_result(response)
  message = '  (' .. (response.query_time / 1000) .. ' ms'
  if response.id == 1 then
    message = message .. ', ' .. response.resultset.row_count .. ' row' .. s(response.resultset.row_count)
  elseif response.id == 2 then
    message = message .. ', ' .. response.resultset.affected_rows .. ' row' .. s(response.resultset.affected_rows) .. ' inserted, id: ' .. response.resultset.insert_id
  elseif response.id == 3 then
    message = message .. ', ' .. response.resultset.affected_rows .. ' row' .. s(response.resultset.affected_rows) .. ' affected'
  end
  message = message .. ')\n'
  log(message)
  print(message)
end

function log_query(message, query)
  date = os.date('%Y-%m-%d %H:%M:%S')
  print(date .. ansicolors.yellow .. ' [' .. message .. ']' .. ansicolors.reset .. '\n  ' .. highlightQuery(query))
  output = date .. '\n  ' .. query .. ';'
  log(output)
end

function log_other(message, data)
  date = os.date('%Y-%m-%d %H:%M:%S')
  text = ' [' .. message .. ']'
  output = date .. text
  if data == '' then
    if message == 'QUIT' then
      print(date .. ansicolors.yellow .. text .. ansicolors.reset .. ' ----------------------------------------------------\n')
    else
      print(date .. ansicolors.yellow .. text .. ansicolors.reset)
    end
  else
    output = output .. ': ' .. data
    print(date .. ansicolors.yellow .. text .. ansicolors.reset .. ': ' .. data)
  end
  log(output .. '\n')
end

function log(line)
  local file = io.open("C:\\log\\mysql-proxy\\querry.log", "a")
  file:write(line .. "\n")
  file:flush()
  file:close()
end

function highlightQuery(sql)
  sql = sql:gsub('[^,. \t\n\r()\\\\*/+-%&|<>=]+', function (word)
    return hightlightWord(word)
  end)
  --sql = sql:gsub('[\'"][^\'"]*[\'"]', function (word)
  --  return word:gsub('%c[', '')
  --end)
  --return sql:gsub('[\'"][^\'"]*[\'"]', function (string)
  --  return ansicolors.red .. string .. ansicolors.reset
  --end)
  return sql
end

function hightlightWord(word)
  words = {
    -- transactions
    BEGIN = 0, START = 0, COMMIT = 0, ROLLBACK = 0, TRANSACTION = 0, RELEASE = 0, TO = 0, SAVEPOINT = 0, LOCK = 0, UNLOCK = 0, UNDO = 0,
    
    -- administration
    CREATE = 1, ALTER = 1, DROP = 1, KILL = 1, GRANT = 1, REVOKE = 1, USAGE = 1, PRAGMA = 1,
    CHECK = 1, ANALYZE = 1, VACUUM = 1, OPTIMIZE = 1, PURGE = 1,
    SHOW = 1, DESCRIBE = 1, EXPLAIN = 1, QUERY = 1, PLAN = 1,
    SCHEMA = 1, DATABASE = 1, TABLE = 1, VIEW = 1, COLUMN = 1, INDEX = 1, TRIGGER = 1, PARTITION = 1, VIRTUAL = 1, TEMPORARY = 1, TEMP = 1,
    CONSTRAINT = 1, PRIMARY = 1, UNIQUE = 1, FOREIGN = 1, KEY = 1, KEYS = 1, DEFAULT = 1, AUTOINCREMENT = 1, CONFLICT = 1, CASCADE = 1, RESTRICT = 1,
    RENAME = 1, ADD = 1, CHANGE = 1, BEFORE = 1, AFTER = 1, INSTEAD = 1, OF = 1, FOR = 1, EACH = 1, ROW = 1, COMMENT = 1, ENGINE = 1, PREFERENCES = 1,

    -- querries
    SELECT = 1, INSERT = 1, REPLACE = 1, UPDATE = 1, DELETE = 1, TRUNCATE = 1, SET = 1, DO = 1, CALL = 1, LOAD = 1, USE = 1, DELIMITER = 1,
    UNION = 1, INTERSECT = 1, EXCEPT = 1, WITH = 1, RECURSIVE = 1,
    INTO = 1, OUTFILE = 1, INFILE = 1, NAMES = 1, LINES = 1, OPTIONALLY = 1, TERMINATED = 1, ENCLOSED = 1, ESCAPED = 1, 
    FROM = 1, JOIN = 1, STRAIGHT_JOIN = 1, NATURAL = 1, LEFT = 1, RIGHT = 1, CROSS = 1, INNER = 1, OUTER = 1, ON = 1, USING = 1, DUAL = 1,
    WHERE = 1, HAVING = 1, 
    ORDER = 1, GROUP = 1, BY = 1, ASC = 1, DESC = 1, ROLLUP = 1,
    LIMIT = 1, OFFSET = 1, FETCH = 1, NEXT = 1,
    AS = 1, VALUES = 1, DELAYED = 1, HIGH_PRIORITY = 1, LOW_PRIORITY = 1, FORCE = 1, INDEXED = 1, DUPLICATE = 1,

    -- procedures
    CASE = 1, WHEN = 1, IF = 1, THEN = 1, ELSE = 1, ELSEIF = 1, END = 1, RETURN = 1, LEAVE = 1, EXIT = 1,
      UNTIL = 1, WHILE = 1, CONDITION = 1, EACH = 1, LOOP = 1,
    FUNCTION = 1, PROCERURE = 1, OUT = 1, INOUT = 1, READS = 1, MODIFIES = 1, SQL = 1, DATA = 1, DETERMINISTIC = 1, DEFINER = 1, RETURNS = 1, CHARSET = 1,
    DECLARE = 1, CONTINUE = 1, HANDLER = 1, FOR = 1, FOUND = 1, CURSOR = 1, OPEN = 1, CLOSE = 1, ITERATE = 1, REPEAT = 1,
    RAISE = 1, IGNORE = 1, ABORT = 1, FAIL = 1, SIGNAL = 1, RESIGNAL = 1, SQLSTATE = 1, SQLEXCEPTION = 1, SQLWARNING = 1,

    -- operators
    DISTINCT = 2, DISTINCTROW = 2, ALL = 2, ANY = 2, EXISTS = 2, COLLATE = 2,
    IS = 2, IN = 2, LIKE = 2, BETWEEN = 2, RLIKE = 2, REGEXP = 2, MATCH = 2, GLOB = 2, NOT = 2, DIV = 2, MOD = 2, AND = 2, OR = 2, XOR = 2,

    -- values
    NULL = 3, FALSE = 3, TRUE = 3, NEW = 3, OLD = 3,

    -- types
    UNSIGNED = 4, SIGNED = 4, SENSITIVE = 4, ASENSITIVE = 4,
    TINYINT = 4, SMALLINT = 4, MEDIUMINT = 4, INT = 4, BIGINT = 4, INT1 = 4, INT2 = 4, INT3 = 4, INT4 = 4, INT8 = 4, INTEGER = 4, LONG = 4, MIDDLEINT = 4,
    DECIMAL = 4, NUMERIC = 4, FLOAT = 4, FLOAT4 = 4, FLOAT8 = 4, REAL = 4, SINGLE = 4, DOUBLE = 4, PRECISION = 4,
    DATE = 4, DATETIME = 4, TIME = 4, TIMESTAMP = 4, YEAR = 4,
    CHAR = 4, VARCHAR = 4, TINYTEXT = 4, TEXT = 4, MEDIUMTEXT = 4, LONGTEXT = 4, FULLTEXT = 4, VARYING = 4, ZEROFILL = 4,
    BINARY = 4, VARBINARY = 4, TINYBLOB = 4, BLOB = 4, MEDIUMBLOB = 4, LONGBLOB = 4,
    BIT = 4, ENUM = 4, -- SET = 4,
    SPATIAL = 4, GEOMETRY = 4, POINT = 4, LINESTRING = 4, POLYGON = 4, MULTIPOINT = 4, MULTILINESTRING = 4, MULTIPOLYGON = 4, GEOMETRYCOLLECTION = 4,

    -- aggregate functions
    COUNT = 5, SUM = 5, AVG = 5, MIN = 5, MAX = 5, GROUP_CONCAT = 5, SEPARATOR = 5,

    -- other functions
    CAST = 6, CONVERT = 6,
    NOW = 6, DATEDIFF = 6, DATEADD = 6, DATESUB = 6,
    INTERVAL = 6, DAY_HOUR = 6, DAY_MICROSECOND = 6, DAY_MINUTE = 6, DAY_SECOND = 6, HOUR_MICROSECOND = 6, HOUR_MINUTE = 6,
      HOUR_SECOND = 6, MINUTE_MICROSECOND = 6, MINUTE_SECOND = 6, SECOND_MICROSECOND = 6, YEAR_MONTH = 7,
    LENGTH = 6, CONCAT = 6, SUBSTR = 6, LOCATE = 6, TRIM = 6, BOTH = 6, LEADING = 6, TRAILING = 6,
    LAST_INSERT_ID = 6, ROW_COUNT = 6,

    -- constants
    CURRENT_TIME = 7, CURRENT_DATE = 7, CURRENT_TIMESTAMP = 7, CURRENT_USER = 7, LOCALTIME = 7, LOCALTIMESTAMP = 7, UTC_DATE = 7, UTC_TIME = 7, UTC_TIMESTAMP = 7
  }

  if word:match('^[%d.]+$') or words[word] == 3 then
    return ansicolors.red .. word .. ansicolors.reset
  elseif words[word] == 0 then
    return ansicolors.cyan .. ansicolors.bright .. word .. ansicolors.reset
  elseif words[word] == 1 or words[word] == 2 then
    return ansicolors.cyan .. word .. ansicolors.reset
  elseif words[word] == 5 or words[word] == 6 or words[word] == 7 then
    return ansicolors.cyan .. word .. ansicolors.reset
  else
    return ansicolors.black .. ansicolors.bright .. word .. ansicolors.reset
  end
end
