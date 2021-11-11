//
// This template implements an eponymous-only virtual table with a rowid and
// two columns named "a" and "b".  The table as 10 rows with fixed integer
// values. Usage example:
//
// sqlite> .load ./templatevtab
// sqlite> SELECT rowid, a, b FROM templatevtab;
// 1|1001|2001
// 2|1002|2002
// 3|1003|2003
// 4|1004|2004
// 5|1005|2005
// 6|1006|2006
// 7|1007|2007
// 8|1008|2008
// 9|1009|2009
//

const std = @import("std");
const assert = std.debug.assert;
const c = @import("./c.zig").c;
const sqlite3_allocator = @import("./sqlite3_allocator.zig");

// sqlite3_api has a meaningful value once 
// this library is loaded by sqlite3 and
// sqlite3_series_init is called.
var sqlite3_api: *c.sqlite3_api_routines = undefined;

// Allows to use a different allocator for testing
// Idea from https://zig.news/geo_ant/low-ish-level-gpio-on-the-raspberry-pi-with-zig-1cn3
// https://github.com/geo-ant/zigpio/blob/main/src/gpio.zig#L45
var allocator: *std.mem.Allocator = undefined; 

//
// Cursor is a subclass of sqlite3_vtab_cursor which will
// serve as the underlying representation of a cursor that scans
// over rows of the result
//
const Cursor = struct {
    base: c.sqlite3_vtab_cursor, // Base class
    // Insert new fields here.  For this templatevtab we only keep track
    // of the rowid 
    iRowid: c.sqlite3_int64,      // The rowid 
};

//
// VTab is a subclass of sqlite3_vtab which is
// underlying representation of the virtual table
//
const VTab = struct {
  base: c.sqlite3_vtab,  // Base class
  // Add new fields here, as necessary
};


//
// The templatevtabConnect() method is invoked to create a new
// template virtual table.
//
// Think of this routine as the constructor for VTab objects.
//
// All this routine needs to do is:
//
//    (1) Allocate the VTab object and initialize all fields.
//
//    (2) Tell SQLite (via the sqlite3_declare_vtab() interface) what the
//        result set of queries against the virtual table will look like.
//
pub fn templatevtabConnect(
    db: ?*c.sqlite3, 
    pAux: ?*c_void, 
    argc: c_int, 
    argv: [*c]const [*c]const u8, 
    ppVTab: [*c][*c]c.sqlite3_vtab, 
    pzErr: [*c][*c]u8
) callconv(.C) c_int {
    _ = pAux;
    _ = argc;
    _ = argv;
    _ = pzErr;
    var rc: c_int = c.SQLITE_OK;
    rc = sqlite3_api.*.declare_vtab.?(db, 
        "CREATE TABLE x(a, b)");
    if (rc == c.SQLITE_OK) {
        const pVTab = allocator.create(VTab) catch return c.SQLITE_NOMEM;
        ppVTab.* = &pVTab.*.base;
        _ = sqlite3_api.*.vtab_config.?(db, c.SQLITE_VTAB_INNOCUOUS);
    }
    return rc;
}

// For convenience, define symbolic names for the index to each column.
const templatevtab_a = 0;
const templatevtab_b = 1;

//
// This method is the destructor for VTab objects.
//
pub fn templatevtabDisconnect(pVTab: [*c]c.sqlite3_vtab) callconv(.C) c_int {
    allocator.destroy(@fieldParentPtr(VTab, "base", pVTab));
    return c.SQLITE_OK;
}

//
// SQLite will invoke this method one or more times while planning a query
// that uses the virtual table.  This routine needs to create
// a query plan for each invocation and compute an estimated cost for that
// plan.
//
pub fn templatevtabBestIndex(pVTab: [*c]c.sqlite3_vtab, pIdxInfo: [*c]c.sqlite3_index_info) callconv(.C) c_int {
    _ = pVTab;
    pIdxInfo.*.estimatedCost = @intToFloat(f64, @as(c_int, 10));
    pIdxInfo.*.estimatedRows = 10;
    return c.SQLITE_OK;
}  

//
// This method is called to "rewind" the templatevtab_cursor object back
// to the first row of output.  This method is always called at least
// once prior to any call to templatevtabColumn() or templatevtabRowid() or 
// templatevtabEof().
//
pub fn templatevtabFilter(
    pCursor: [*c]c.sqlite3_vtab_cursor, 
    idxNum: c_int, 
    idxStr: [*c]const u8, 
    argc: c_int, 
    argv: [*c]?*c.sqlite3_value
) callconv(.C) c_int {
    _ = pCursor;
    _ = idxNum;
    _ = idxStr;
    _ = argc;
    _ = argv;
    var pCur = @fieldParentPtr(Cursor, "base", pCursor);
    pCur.*.iRowid = 1;
    return c.SQLITE_OK;
}

//
// Constructor for a new Cursor object.
//
pub fn templatevtabOpen(pVTab: [*c]c.sqlite3_vtab, ppCursor: [*c][*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    _ = pVTab;
    const pCur = allocator.create(Cursor) catch return c.SQLITE_NOMEM;
    ppCursor.* = &pCur.*.base;
    return c.SQLITE_OK;
}

//
// Destructor for a templatevtab_cursor.
//
pub fn templatevtabClose(pCursor: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    allocator.destroy(@fieldParentPtr(Cursor, "base", pCursor));
    return c.SQLITE_OK;
}

//
// Return values of columns for the row at which the templatevtab_cursor
// is currently pointing.
//
pub fn templatevtabColumn(pCursor: [*c]c.sqlite3_vtab_cursor, cxt: ?*c.sqlite3_context, n: c_int) callconv(.C) c_int {
    const pCur = @fieldParentPtr(Cursor, "base", pCursor);
    if (n == templatevtab_a) {
        sqlite3_api.*.result_int.?(cxt, 1000 + @intCast(c_int, pCur.*.iRowid));
    } else {
        assert(n == templatevtab_b);
        sqlite3_api.*.result_int.?(cxt, 2000 + @intCast(c_int, pCur.*.iRowid));
    }
    return c.SQLITE_OK;
}

//
// Return the rowid for the current row.  In this implementation, the
// rowid is the same as the output value.
//
pub fn templatevtabRowid(pCursor: [*c]c.sqlite3_vtab_cursor, pRowid: [*c]c.sqlite3_int64) callconv(.C) c_int {
    var pCur = @fieldParentPtr(Cursor, "base", pCursor);
    pRowid.* = pCur.*.iRowid;
    return c.SQLITE_OK;
}

//
// Advance a Cursor to its next row of output.
//
pub fn templatevtabNext(pCursor: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var pCur = @fieldParentPtr(Cursor, "base", pCursor);
    pCur.*.iRowid += 1;
    return c.SQLITE_OK;
}

//
// Return TRUE if the cursor has been moved off of the last
// row of output.
//
pub fn templatevtabEof(pCursor: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var pCur = @fieldParentPtr(Cursor, "base", pCursor);
    if (pCur.*.iRowid>=10) {
        return 1;
    }
    return 0;
}

// "eponymous virtual tables": exist automatically in the "main" schema of every database connection in which their module is registered
// To make your VT eponymous, make the xCreate method NULL.

//
// This following structure defines all the methods for the 
// virtual table.
//
const templatevtabModule = c.sqlite3_module {
    .iVersion = 0,
    .xCreate = null,
    .xConnect = templatevtabConnect,
    .xBestIndex = templatevtabBestIndex,
    .xDisconnect = templatevtabDisconnect,
    .xDestroy = null,
    .xOpen = templatevtabOpen,
    .xClose = templatevtabClose,
    .xFilter = templatevtabFilter,
    .xNext = templatevtabNext,
    .xEof = templatevtabEof,
    .xColumn = templatevtabColumn,
    .xRowid = templatevtabRowid,
    .xUpdate = null,
    .xBegin = null,
    .xSync = null,
    .xCommit = null,
    .xRollback = null,
    .xFindFunction = null,
    .xRename = null,
    .xSavepoint = null,
    .xRelease = null,
    .xRollbackTo = null,
    .xShadowName = null,
};

pub export fn sqlite3_templatevtab_init(db: ?*c.sqlite3, pzErrMsg: [*c][*c]u8, pApi: [*c]c.sqlite3_api_routines) c_int {
    _ = pzErrMsg;
    var rc: c_int = c.SQLITE_OK;
    sqlite3_api = pApi.?;
    allocator = sqlite3_allocator.init(pApi.?);
    rc = sqlite3_api.*.create_module.?(db, "templatevtab", &templatevtabModule, null);
    return rc;
}