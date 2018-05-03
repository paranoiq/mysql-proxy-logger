-- package.path = package.path .. ';C:\\bin'
require("ansicolors")

function string.fromHex(str)
  return (str:gsub('..', function (cc)
    return string.char(tonumber(cc, 16))
  end))
end

function string.toHex(str)
  return (str:gsub('.', function (c)
    return string.format('%02X', string.byte(c))
  end))
end

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
  local vid = tostring(proxy.connection.server.mysqld_version)
  local version = vid:sub(1, 1) .. '.' .. vid:sub(3, 3) .. '.' .. vid:sub(4)
  log_other('CONNECT', version .. ', ' .. proxy.connection.client.username .. ', ' .. proxy.connection.client.default_db)
end

function read_query(packet)
  local type = packet:byte()
  local data = ''
  local message
  local query, id

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
    local init = query:sub(0, 6):upper();
    if init == 'SELECT' then
      id = 1
    elseif init == 'INSERT' or init == 'REPLAC' then
      id = 2
    elseif init == 'UPDATE' or init == 'DELETE' then
      id = 3
    else
      id = 0
    end

    log_query(message, query)

    if init == 'SELECT' then
      proxy.queries:append(id, packet, {resultset_is_needed = true})
    end
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

  local err = pcall(log_other(message, data))
  if err then
    print(err.code)
  end
end

function read_query_result(response)
  local message = '  (' .. (response.query_time / 1000) .. ' ms'
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
  local date = os.date('%Y-%m-%d %H:%M:%S')
  print(date .. ansicolors.yellow .. ' [' .. message .. ']' .. ansicolors.reset .. '\n  ' .. highlightQuery(query))
  local output = date .. '\n  ' .. query .. ';'
  log(output)
end

function log_other(message, data)
  local date = os.date('%Y-%m-%d %H:%M:%S')
  local text = ' [' .. message .. ']'
  local output = date .. text
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
  sql = sql:gsub("'(\\0.[^']+)'", function (value)
    value = value:gsub('\\0', string.char(0));
    return "X'" .. string.toHex(value) .. "'";
  end)

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
  local words = {
    -- transactions
    BEGIN = 0, START = 0, COMMIT = 0, ROLLBACK = 0, TRANSACTION = 0, RELEASE = 0, TO = 0, SAVEPOINT = 0, LOCK = 0, UNLOCK = 0, UNDO = 0, ISOLATION = 0, XA = 0,

    -- administration
    CREATE = 1, ALTER = 1, DROP = 1, KILL = 1, GRANT = 1, GRANTS = 1, REVOKE = 1, USAGE = 1, PRAGMA = 1, FLUSH = 1, PRIVILEGES = 1, USER = 1, PASSWORD = 1,
    ANALYZE = 1, CHECK = 1, CHECKSUM = 1, VACUUM = 1, OPTIMIZE = 1, REPAIR = 1, PURGE = 1, CACHE = 1, RESET = 1,
    SHOW = 1, CHARACTER = 1, COLLATION = 1, ENGINE = 1, ENGINES = 1, STATUS = 1, ERRORS = 1, WARNINGS = 1, PLUGINS = 1, CODE = 1,
    DESCRIBE = 1, EXPLAIN = 1, QUERY = 1, PLAN = 1, PROFILE = 1, PROFILES = 1, PROCESSLIST = 1,
    SCHEMA = 1, DATABASE = 1, DATABASES = 1, TABLE = 1, TABLESPACE = 1, VIEW = 1, COLUMN = 1, COLUMNS = 1, INDEX = 1, TRIGGER = 1, PARTITION = 1, VIRTUAL = 1, TEMPORARY = 1, TEMP = 1,
    CONSTRAINT = 1, PRIMARY = 1, UNIQUE = 1, FOREIGN = 1, KEY = 1, KEYS = 1, DEFAULT = 1, AUTOINCREMENT = 1, CONFLICT = 1, CASCADE = 1, RESTRICT = 1,
    RENAME = 1, ADD = 1, CHANGE = 1, BEFORE = 1, AFTER = 1, INSTEAD = 1, OF = 1, FOR = 1, EACH = 1, ROW = 1, COMMENT = 1, PREFERENCES = 1,
    INNODB = 1, MYISAM = 1, FEDERATED = 1, MERGE = 1,
    BINLOG = 1, LOG = 1, RELAYLOG = 1, EVENT = 1, -- EVENTS = 1, TRIGGERS = 1,
    SHUTDOWN = 1, SERVER = 1, CHANGE = 1, STOP = 1, MASTER = 1, SLAVE = 1, HOSTS = 1, REPLICATION = 1, FILTER = 1, SQL_SLAVE_SKIP_COUNTER = 1, SQL_LOG_BIN = 1,
    INSTALL = 1, UNINSTALL = 1, PLUGIN = 1,

    -- queries
    SELECT = 1, INSERT = 1, REPLACE = 1, UPDATE = 1, DELETE = 1, TRUNCATE = 1, SET = 1, DO = 1, CALL = 1, LOAD = 1, USE = 1, DELIMITER = 1,
    UNION = 1, INTERSECT = 1, EXCEPT = 1, WITH = 1, RECURSIVE = 1,
    INTO = 1, OUTFILE = 1, INFILE = 1, NAMES = 1, LINES = 1, OPTIONALLY = 1, TERMINATED = 1, ENCLOSED = 1, ESCAPED = 1,
    FROM = 1, JOIN = 1, STRAIGHT_JOIN = 1, NATURAL = 1, LEFT = 1, RIGHT = 1, CROSS = 1, INNER = 1, OUTER = 1, ON = 1, USING = 1, DUAL = 1,
    WHERE = 1, HAVING = 1,
    ORDER = 1, GROUP = 1, BY = 1, ASC = 1, DESC = 1, ROLLUP = 1,
    LIMIT = 1, OFFSET = 1, FETCH = 1, NEXT = 1,
    AS = 1, VALUES = 1, DELAYED = 1, HIGH_PRIORITY = 1, LOW_PRIORITY = 1, FORCE = 1, INDEXED = 1, DUPLICATE = 1,
    DATA = 1, XML = 1, GLOBAL = 1, LOCAL = 1,
    DEALLOCATE = 1, PREPARE = 1, EXECUTE = 1, STATEMENT = 1,

    -- procedures
    CASE = 1, WHEN = 1, IF = 1, IFNULL = 1, NULLIF = 1, THEN = 1, ELSE = 1, ELSEIF = 1, END = 1, RETURN = 1, LEAVE = 1, EXIT = 1,
      UNTIL = 1, WHILE = 1, CONDITION = 1, EACH = 1, LOOP = 1,
    FUNCTION = 1, PROCEDURE = 1, OUT = 1, INOUT = 1, READS = 1, MODIFIES = 1, SQL = 1, DATA = 1, DETERMINISTIC = 1, DEFINER = 1, RETURNS = 1, CHARSET = 1,
    DECLARE = 1, CONTINUE = 1, HANDLER = 1, FOR = 1, FOUND = 1, CURSOR = 1, OPEN = 1, CLOSE = 1, ITERATE = 1, REPEAT = 1,
    RAISE = 1, IGNORE = 1, ABORT = 1, FAIL = 1, SIGNAL = 1, RESIGNAL = 1, SQLSTATE = 1, SQLEXCEPTION = 1, SQLWARNING = 1, DIAGNOSTICS = 1, ANALYSE = 1,

    -- operators
    DISTINCT = 2, DISTINCTROW = 2, ALL = 2, ANY = 2, EXISTS = 2, COLLATE = 2, GREATEST = 2, LEAST = 2, MATCH = 2, AGAINST = 2, SOUNDS = 2,
    IS = 2, IN = 2, LIKE = 2, BETWEEN = 2, RLIKE = 2, REGEXP = 2, MATCH = 2, GLOB = 2, NOT = 2, DIV = 2, MOD = 2, AND = 2, OR = 2, XOR = 2,

    -- values
    NULL = 3, FALSE = 3, TRUE = 3, NEW = 3, OLD = 3,

    -- types
    UNSIGNED = 4, SIGNED = 4, SENSITIVE = 4, ASENSITIVE = 4, AUTO_INCREMENT = 4,
    TINYINT = 4, SMALLINT = 4, MEDIUMINT = 4, INT = 4, BIGINT = 4, INT1 = 4, INT2 = 4, INT3 = 4, INT4 = 4, INT8 = 4, INTEGER = 4, LONG = 4, MIDDLEINT = 4,
    DEC = 4, DECIMAL = 4, NUMERIC = 4, FLOAT = 4, FLOAT4 = 4, FLOAT8 = 4, REAL = 4, SINGLE = 4, DOUBLE = 4, PRECISION = 4,
    DATE = 4, DATETIME = 4, TIME = 4, TIMESTAMP = 4, YEAR = 4,
    CHAR = 4, VARCHAR = 4, TINYTEXT = 4, TEXT = 4, MEDIUMTEXT = 4, LONGTEXT = 4, FULLTEXT = 4, VARYING = 4, ZEROFILL = 4,
    BINARY = 4, VARBINARY = 4, TINYBLOB = 4, BLOB = 4, MEDIUMBLOB = 4, LONGBLOB = 4,
    BIT = 4, ENUM = 4, -- SET = 4,
    SPATIAL = 4, GEOMETRY = 4, POINT = 4, LINESTRING = 4, POLYGON = 4, MULTIPOINT = 4, MULTILINESTRING = 4, MULTIPOLYGON = 4, GEOMETRYCOLLECTION = 4,

    -- constants
    CURRENT_TIME = 7, CURRENT_DATE = 7, CURRENT_TIMESTAMP = 7, CURRENT_USER = 7, LOCALTIME = 7, LOCALTIMESTAMP = 7, UTC_DATE = 7, UTC_TIME = 7, UTC_TIMESTAMP = 7,

    -- aggregate functions
    AVG = 5, COUNT = 5, GROUP_CONCAT = 5, SEPARATOR = 5, MAX = 5, MIN = 5, STD = 5, STDDEV = 5, STDDEV_POP = 5, STDDEV_SAMP = 5, SUM = 5, VARIANCE = 5, VAR_POP = 5, VAR_SAMP = 5, ANY_VALUE = 5,

    -- misc functions
    COALESCE = 6, DEFAULT = 6, MASTER_POS_WAIT = 6, NAME_CONST = 6, SLEEP = 6, UUID = 6, UUID_SHORT = 6,
      BENCHMARK = 6, COERCIBILITY = 6, CONNECTION_ID = 6, FOUND_ROWS = 6, LAST_INSERT_ID = 6, ROW_COUNT = 6, SESSION_USER = 6, SYSTEM_USER = 6, VERSION = 6,
    -- locks
    GET_LOCK = 6, IS_FREE_LOCK = 6, IS_USED_LOCK = 6, RELEASE_ALL_LOCKS = 6, RELEASE_LOCK = 6,
    -- network
    INET6_ATON = 6, INET6_NTOA = 6, INET_ATON = 6, INET_NTOA = 6, IS_IPV4 = 6, IS_IPV4_COMPAT = 6, IS_IPV4_MAPPED = 6, IS_IPV6 = 6,
    -- date & time
    NOW = 6, ADDDATE = 6, ADDTIME = 6, CONVERT_TZ = 6, CURDATE = 6, CURTIME = 6, DATEDIFF = 6, DATE_ADD = 6, DATE_FORMAT = 6, DATE_SUB = 6, DAYNAME = 6,
      DAYOFMONTH = 6, DAYOFWEEK = 6, DAYOFYEAR = 6, EXTRACT = 6, FROM_DAYS = 6, FROM_UNIXTIME = 6, GET_FORMAT = 6, HOUR = 6, LAST_DAY = 6, MAKEDATE = 6,
      MAKETIME = 6, MICROSECONDS = 6, MINUTE = 6, MONTH = 6, MONTHNAME = 6, PERIOD_ADD = 6, PERIOD_DIFF = 6, QUARTER = 6, SECOND = 6, SEC_TO_TIME = 6,
      STR_TO_DATE = 6, SUBDATE = 6, SUBTIME = 6, SYSDATE = 6, TIMEDIFF = 6, TIMESTAMPADD = 6, TIMESTAMPDIFF = 6, TIME_FORMAT = 6, TIMETOSEC = 6, TO_DAYS = 6,
      TO_SECONDS = 6, UNIX_TIMESTAMP = 6, WEEK = 6, WEEKDAY = 6, WEEKOFYEAR = 6, YEAR = 6, YEARWEEK = 6,
    INTERVAL = 6, DAY_HOUR = 6, DAY_MICROSECOND = 6, DAY_MINUTE = 6, DAY_SECOND = 6, HOUR_MICROSECOND = 6, HOUR_MINUTE = 6,
      HOUR_SECOND = 6, MINUTE_MICROSECOND = 6, MINUTE_SECOND = 6, SECOND_MICROSECOND = 6, YEAR_MONTH = 6,
    -- encryption
    AES_DECRYPT = 6, AES_ENCRYPT = 6, COMPRESS = 6, DECODE = 6, ENCODE = 6, MD5 = 6, OLD_PASSWORD = 6, RANDOM_BYTES = 6, SHA1 = 6, SHA2 = 6,
      UNCOMPRESS = 6, UNCOMPRESSED_LENGTH = 6, VALIDATE_PASSWORD_STRENGTH = 6,
      ASYMMETRIC_DECRYPT = 6, ASYMMETRIC_DERIVE = 6, ASYMMETRIC_ENCRYPT = 6, ASYMMETRIC_SIGN = 6, ASYMMETRIC_VERIFY = 6, CREATE_ASYMMETRIC_PRIV_KEY = 6, CREATE_ASYMMETRIC_PUB_KEY = 6,
      CREATE_DH_PARAMETERS = 6, CREATE_DIGEST = 6,
    -- gtid
    GTID_SUBSET = 6, GTID_SUBTRACT = 6, WAIT_FOR_EXECUTED_GTID_SET = 6, WAIT_UNTIL_SQL_THREAD_AFTER_GTIDS = 6,
    -- json
    JSON_APPEND = 6, JSON_ARRAY = 6, JSON_ARRAY_APPEND = 6, JSON_ARRAY_INSERT = 6, JSON_CONTAINS = 6, JSON_CONTAINS_PATH = 6, JSON_DEPTH = 6, JSON_EXTRACT = 6, JSON_INSERT = 6, JSON_KEYS = 6,
      JSON_LENGTH = 6, JSON_MERGE = 6, JSON_OBJECT = 6, JSON_QUOTE = 6, JSON_REMOVE = 6, JSON_REPLACE = 6, JSON_SEARCH = 6, JSON_SET = 6, JSON_TYPE = 6, JSON_UNQUOTE = 6, JSON_VALID = 6,
    -- math
    BIT_AND = 6, BIT_COUNT = 6, BIT_OR = 6, BIT_XOR = 6,
    ABS = 6, ACOS = 6, ASIN = 6, ATAN = 6, ATAN2 = 6, BIN = 6, CEIL = 6, CEILING = 6, CONV = 6, COS = 6, COT = 6, CRC32 = 6, DEGREES = 6, DIV = 6, EXP = 6, FLOOR = 6, LN = 6, LOG = 6,
      LOG10 = 6, LOG2 = 6, MOD = 6, PI = 6, POW = 6, POWER = 6, RADIANS = 6, RAND = 6, ROUND = 6, SIGN = 6, SIN = 6, SQRT = 6, TAN = 6, TRUNCATE = 6,
    -- strings
    ASCII = 6, BIT_LENGTH = 6, CAST = 6, CONCAT = 6, CONCAT_WS = 6, CONVERT = 6, ELT = 6, EXPORT_SET = 6, EXTRACTVALUE = 6, FIELD = 6, FIND_IN_SET = 6, FORMAT = 6, FROM_BASE64 = 6,
      HEX = 6, INSTR = 6, LCASE = 6, LENGTH = 6, LOAD_FILE = 6, LOCATE = 6, LOWER = 6, LPAD = 6, LTRIM = 6, MAKE_SET = 6, MID = 6, OCT = 6, OCTET_LENGTH = 6, ORD = 6, POSITION = 6,
      QUOTE = 6, REVERSE = 6, RPAD = 6, RTRIM = 6, SOUNDEX = 6, SPACE = 6, STRCMP = 6, SUBSTR = 6, SUBSTRING = 6, SUBSTRING_INDEX = 6, TO_BASE64 = 6,
      TRIM = 6, BOTH = 6, LEADING = 6, TRAILING = 6, UCASE = 6, UNHEX = 6, UPDATEXML = 6, UPPER = 6, WEIGHT_STRING = 6,
    -- geometry
    DIMENSION = 6, ST_DIMENSION = 6, ENVELOPE = 6, ST_ENVELOPE = 6, GEOMETRYTYPE = 6, ST_GEOMETRYTYPE = 6, ISEMPTY = 6, ST_ISEMPTY = 6, ISSIMPLE = 6, ST_ISSIMPLE = 6,
      SRID = 6, ST_SRID = 6, CONTAINS = 6, ST_CONTAINS = 6, CROSSES = 6, ST_CROSSES = 6, DISJOINT = 6, ST_DISJOINT = 6, DISTANCE = 6, ST_DISTANCE = 6,
      EQUALS = 6, ST_EQUALS = 6, INTERSECTS = 6, ST_INTERSECTS = 6, OVERLAPS = 6, ST_OVERLAPS = 6, TOUCHES = 6, ST_TOUCHES = 6, WITHIN = 6, ST_WITHIN = 6,
      BUFFER = 6, ST_BUFFER = 6, ST_BUFFER_STRATEGY = 6, CONVEXHULL = 6, ST_CONVEXHULL = 6, ST_DIFFERENCE = 6, GEOMETRYN = 6, ST_GEOMETRYN = 6, ST_INTERSECTION = 6,
      NUMGEOMETRIES = 6, ST_NUMGEOMETRIES = 6, ST_SYMDIFFERENCE = 6, ST_UNION = 6,
      ENDPOINT = 6, ST_ENDPOINT = 6, GLENGTH = 6, ST_LENGTH = 6, ISCLOSED = 6, ST_ISCLOSED = 6, NUMPOINTS = 6, ST_NUMPOINTS = 6, POINTN = 6, ST_POINTN = 6, STARTPOINT = 6, ST_STARTPOINT = 6,
      MBRCONTAINS = 6, MBRCOVEREDBY = 6, MBRCOVERS = 6, MBRDISJOINT = 6, MBREQUAL = 6, MBREQUALS = 6, MBRINTERSECTS = 6, MBROVERLAPS = 6, MBRTOUCHES = 6, MBRWITHIN = 6,
      ST_ASGEOJSON = 6, ST_DISTANCE_SPHERE = 6, ST_GEOHASH = 6, ST_GEOMFROMGEOJSON = 6, ST_ISVALID = 6, ST_LATFROMGEOHASH = 6, ST_LONGFROMGEOHASH = 6, ST_MAKEENVELOPE = 6,
      ST_POINTFROMGEOHASH = 6, ST_SIMPLIFY = 6, ST_VALIDATE = 6, X = 6, ST_X = 6, Y = 6, ST_Y = 6,
      AREA = 6, ST_AREA = 6, CENTROID = 6, ST_CENTROID = 6, EXTERIORRING = 6, ST_EXTERIORRING = 6, INTERIORRINGN = 6, ST_INTERIORRINGN = 6, NUMINTERIORRINGS = 6, ST_NUMINTERIORRINGS = 6,
      ASBINARY = 6, ST_ASBINARY = 6, ASTEXT = 6, ST_ASTEXT = 6, GEOMCOLLFROMWKB = 6, ST_GEOMCOLLFROMWKB = 6, GEOMFROMWKB = 6, ST_GEOMFROMWKB = 6, LINEFROMWKB = 6, ST_LINEFROMWKB = 6,
      MLINEFROMWKB = 6, ST_MLINEFROMWKB = 6, MPOINTFROMWKB = 6, ST_MPOINTFROMWKB = 6, MPOLYFROMWKB = 6, ST_MPOLYFROMWKB = 6, POINTFROMWKB = 6, ST_POINTFROMWKB = 6, POLYFROMWKB = 6, ST_POLYFROMWKB = 6,
      GEOMCOLLFROMTEXT = 6, ST_GEOMCOLLFROMTEXT = 6, GEOMFROMTEXT = 6, ST_GEOMFROMTEXT = 6, LINEFROMTEXT = 6, ST_LINEFROMTEXT = 6, MLINEFROMTEXT = 6, ST_MLINEFROMTEXT = 6,
      MPOINTFROMTEXT = 6, ST_MPOINTFROMTEXT = 6, MPOLYFROMTEXT = 6, ST_MPOLYFROMTEXT = 6, POINTFROMTEXT = 6, ST_POINTFROMTEXT = 6, POLYFROMTEXT = 6, ST_POLYFROMTEXT = 6,
  }

  local upper = word:upper();

  if word:match('^[%d.]+$') or words[upper] == 3 then
    return ansicolors.red .. upper .. ansicolors.reset
  elseif words[upper] == 0 then
    return ansicolors.cyan .. ansicolors.bright .. upper .. ansicolors.reset
  elseif words[upper] == 1 or words[upper] == 2 then
    return ansicolors.cyan .. upper .. ansicolors.reset
  elseif words[upper] == 5 or words[upper] == 6 or words[upper] == 7 then
    return ansicolors.cyan .. upper .. ansicolors.reset
  else
    return ansicolors.black .. ansicolors.bright .. word .. ansicolors.reset
  end
end
